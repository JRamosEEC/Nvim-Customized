/*!
Defines a very high level "search worker" abstraction.

A search worker manages the high level interaction points between the matcher
(i.e., which regex engine is used), the searcher (i.e., how data is actually
read and matched using the regex engine) and the printer. For example, the
search worker is where things like preprocessors or decompression happens.
*/

use std::{io, path::Path};

use {bstr::ByteVec, grep::matcher::Matcher, termcolor::WriteColor};

/// The result of executing a search.
#[derive(Clone, Debug)]
pub(crate) struct SearchResult {
    file_name: String,
    line_number: u32, //If I could get like a u24 size wise that would make way more sense, maybe 3 u8's?
    matched_bytes: Vec<u8>,
}
impl SearchResult {
    pub(crate) fn new(file_name: String, line_number: u32, matched_bytes: Vec<u8>) -> SearchResult {
        return SearchResult { file_name, line_number, matched_bytes };
    }
}

//This will have to store search results
#[derive(Debug, Clone)]
pub(crate) struct SearchResults {
    results_store: Vec<SearchResult>
}
impl SearchResults {
    pub(crate) fn new() -> SearchResults {
        return SearchResults { results_store: vec![] };
    }

    pub(crate) fn store_result(&mut self, search_result: SearchResult) {
        self.results_store.push(search_result);
    }

    pub(crate) fn get_mut(&mut self) -> &mut Vec<SearchResult> {
        return &mut self.results_store;
    }
}

//Custom sink that doesn't use underlying printer instead keeps the vector of byte or converted string
#[derive(Clone, Debug)]
pub struct CustomSink {
    match_count: u64,
    results_store: SearchResults,
}

impl CustomSink {
    pub fn new() -> CustomSink {
        return CustomSink { match_count: 0, results_store: SearchResults::new() };
    }

    pub fn get_results(&mut self) -> &mut SearchResults {
        return &mut self.results_store;
    }

    pub fn has_match(&self) -> bool {
        self.match_count > 0
    }

    pub fn match_count(&self) -> u64 {
        self.match_count
    }
}
impl grep::searcher::Sink for CustomSink {
    type Error = io::Error;

    fn matched(
        &mut self,
        searcher: &grep::searcher::Searcher,
        mat: &grep::searcher::SinkMatch<'_>,
    ) -> Result<bool, io::Error> {
        self.match_count += 1;

        let line_number = match mat.line_number() {
            Some(line_number) => line_number,
            None => 0, //Safe default
        };

        self.results_store.store_result(
            SearchResult::new(
                String::from(""),
                line_number.try_into().unwrap(), //Going to bank no file being this large in our codebase
                mat.bytes().to_vec() //Maybe more efficient way to do this?
            )
        );
        return Ok(true);
    }

    fn begin(&mut self, _searcher: &grep::searcher::Searcher) -> Result<bool, io::Error> {
        self.match_count = 0;
        return Ok(true);
    }
}

/// The configuration for the search worker.
#[derive(Clone, Debug)]
struct Config {
    preprocessor: Option<std::path::PathBuf>,
    preprocessor_globs: ignore::overrides::Override,
    search_zip: bool,
    binary_implicit: grep::searcher::BinaryDetection,
    binary_explicit: grep::searcher::BinaryDetection,
}

impl Default for Config {
    fn default() -> Config {
        Config {
            preprocessor: None,
            preprocessor_globs: ignore::overrides::Override::empty(),
            search_zip: false,
            binary_implicit: grep::searcher::BinaryDetection::quit(0),
            binary_explicit: grep::searcher::BinaryDetection::quit(0),
        }
    }
}

/// A builder for configuring and constructing a search worker.
#[derive(Clone, Debug)]
pub(crate) struct SearchWorkerBuilder {
    config: Config,
    command_builder: grep::cli::CommandReaderBuilder,
    decomp_builder: grep::cli::DecompressionReaderBuilder,
}

impl Default for SearchWorkerBuilder {
    fn default() -> SearchWorkerBuilder {
        SearchWorkerBuilder::new()
    }
}

impl SearchWorkerBuilder {
    /// Create a new builder for configuring and constructing a search worker.
    pub(crate) fn new() -> SearchWorkerBuilder {
        let mut cmd_builder = grep::cli::CommandReaderBuilder::new();
        cmd_builder.async_stderr(true);

        let mut decomp_builder = grep::cli::DecompressionReaderBuilder::new();
        decomp_builder.async_stderr(true);

        SearchWorkerBuilder {
            config: Config::default(),
            command_builder: cmd_builder,
            decomp_builder,
        }
    }

    pub(crate) fn build(
        &self,
        matcher: PatternMatcher,
        searcher: grep::searcher::Searcher,
    ) -> SearchWorker {
        let config = self.config.clone();
        let command_builder = self.command_builder.clone();
        let decomp_builder = self.decomp_builder.clone();
        SearchWorker {
            config,
            command_builder,
            decomp_builder,
            matcher,
            searcher,
            results_store: CustomSink::new(),
        }
    }
}

/// The pattern matcher used by a search worker.
#[derive(Clone, Debug)]
pub(crate) enum PatternMatcher {
    RustRegex(grep::regex::RegexMatcher),
    //#[cfg(feature = "pcre2")]
    //PCRE2(grep::pcre2::RegexMatcher),
}

#[derive(Clone, Debug)]
pub(crate) struct SearchWorker {
    config: Config,
    command_builder: grep::cli::CommandReaderBuilder,
    decomp_builder: grep::cli::DecompressionReaderBuilder,
    matcher: PatternMatcher,
    searcher: grep::searcher::Searcher,
    results_store: CustomSink,
}

impl SearchWorker {
    pub(crate) fn get_results(&mut self) -> &mut SearchResults {
        return self.results_store.get_results();
    }

    pub(crate) fn search(&mut self, haystack: &crate::haystack::Haystack) -> bool {
        self.searcher.set_binary_detection(
            match haystack.is_explicit() {
                true => self.config.binary_explicit.clone(),
                false => self.config.binary_implicit.clone()
            }
        );
        return self.search_path(haystack.path());
    }

    fn search_path(&mut self, path: &Path) -> bool {
        use self::PatternMatcher::*;
        match self.matcher {
            RustRegex(ref m) => {
                let _ = self.searcher.search_path(&m, path, &mut self.results_store);

                for result in self.results_store.get_results().get_mut().iter_mut() {
                    result.file_name = path.to_string_lossy().to_string();
                }
                return self.results_store.has_match();
            },
            //#[cfg(feature = "pcre2")]
            //PCRE2(ref m) => search_path(m, searcher, results_store, path),
        }
    }
}
