/*!
Defines a very high level "search worker" abstraction.

A search worker manages the high level interaction points between the matcher
(i.e., which regex engine is used), the searcher (i.e., how data is actually
read and matched using the regex engine) and the printer. For example, the
search worker is where things like preprocessors or decompression happens.
*/

use std::{io, path::Path};

use {bstr::ByteVec, grep::matcher::Matcher, termcolor::WriteColor};

//use arrayvec::ArrayVec;

/// The result of executing a search.
#[derive(Clone, Debug)]
pub(crate) struct SearchResult {
    //Fuck this I have a better idea (See main.rs)
    //Likely rename this to ThreadSearchResult & maybe ThreadSearchResults
    //These fill with the small easy fill data and they supply the main.rs Results
    //This eleminates dealing with lifetimes in the thread which leaks into underlying searcher code
    //
    //file_name: &str,
    //file_name: String,
    file_name: Option<String>,
    //file_name: Option<&str>,
    //file_name: Option<&Path>,
    line_number: u16, //If I could get like a u24 size wise that would make way more sense, maybe 3 u8's?
    matched_bytes: Vec<u8>,
    //This is two things I can try
    //matched_bytes: [u8; 50],
    //matched_bytes: ArrayVec<u8>,
}
impl SearchResult {
    pub(crate) fn new(file_name: Option<String>, line_number: u16, matched_bytes: Vec<u8>) -> SearchResult {
        return SearchResult { file_name, line_number, matched_bytes };
    }

    //pub(crate) fn new(line_number: u16, matched_bytes: Vec<u8>) -> SearchResult {
    //    return SearchResult { line_number, matched_bytes };
    //}

    pub(crate) fn get_line_number(&mut self) -> u16 {
        return self.line_number;
    }

    pub(crate) fn get_matched_bytes(&mut self) -> &Vec<u8> {
        return &self.matched_bytes;
    }

    pub(crate) fn set_file_name(&mut self, file_name: Option<String>) {
        self.file_name = file_name;
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

    pub(crate) fn has_results(&self) -> bool {
        return self.results_store.len() > 0;
    }

    pub(crate) fn consume_results(self) -> Vec<SearchResult> {
        return self.results_store;
    }
}

//Custom sink that doesn't use underlying printer instead keeps the vector of byte or converted string
#[derive(Clone, Debug)]
pub struct CustomSink {
    match_count: u32,
    results_store: SearchResults,
}

impl CustomSink {
    pub(crate) fn new() -> CustomSink {
        return CustomSink { match_count: 0, results_store: SearchResults::new() };
    }

    pub(crate) fn get_results(&mut self) -> &mut SearchResults {
        return &mut self.results_store;
    }

    pub(crate) fn has_match(&self) -> bool {
        self.match_count > 0
    }

    pub(crate) fn match_count(&self) -> u32 {
        self.match_count
    }

    pub(crate) fn consume_sink_results(self) -> SearchResults {
        return self.results_store;
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
                None,
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
///
/// Among a few other things, the configuration primarily controls the way we
/// show search results to users at a very high level.
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

    /// Create a new search worker using the given searcher, matcher and
    /// printer.
    pub(crate) fn build<W: WriteColor>(
        &self,
        matcher: PatternMatcher,
        searcher: grep::searcher::Searcher,
        printer: grep::printer::Standard<W>,
    ) -> SearchWorker<W> {
        let config = self.config.clone();
        let command_builder = self.command_builder.clone();
        let decomp_builder = self.decomp_builder.clone();
        SearchWorker {
            config,
            command_builder,
            decomp_builder,
            matcher,
            searcher,
            printer,
        }
    }
}

/// The result of executing a search.
///
/// Generally speaking, the "result" of a search is sent to a printer, which
/// writes results to an underlying writer such as stdout or a file. However,
/// every search also has some aggregate statistics or meta data that may be
/// useful to higher level routines.
#[derive(Clone, Debug, Default)]
pub(crate) struct SearchResult {
    has_match: bool,
}

/// The pattern matcher used by a search worker.
#[derive(Clone, Debug)]
pub(crate) enum PatternMatcher {
    RustRegex(grep::regex::RegexMatcher),
    #[cfg(feature = "pcre2")]
    PCRE2(grep::pcre2::RegexMatcher),
}

/// A worker for executing searches.
///
/// It is intended for a single worker to execute many searches, and is
/// generally intended to be used from a single thread. When searching using
/// multiple threads, it is better to create a new worker for each thread.
#[derive(Clone, Debug)]
pub(crate) struct SearchWorker<W> {
    config: Config,
    command_builder: grep::cli::CommandReaderBuilder,
    decomp_builder: grep::cli::DecompressionReaderBuilder,
    matcher: PatternMatcher,
    searcher: grep::searcher::Searcher,
    printer: grep::printer::Standard<W>,
}

impl<W: WriteColor> SearchWorker<W> {
    /// Execute a search over the given haystack.
    pub(crate) fn search(
        &mut self,
        haystack: &crate::haystack::Haystack,
    ) -> io::Result<SearchResult> {
impl SearchWorker {
    pub(crate) fn get_results(&mut self) -> &mut SearchResults {
        return self.results_store.get_results();
    }

    //Fuck I think this pattern would help alot too but the mut is created outside of multithreading
    pub(crate) fn consume_searcher_results(self) -> SearchResults {
        return self.results_store.consume_sink_results();
    }

    pub(crate) fn search(&mut self, haystack: &crate::haystack::Haystack) -> bool {
        self.searcher.set_binary_detection(
            match haystack.is_explicit() {
                true => self.config.binary_explicit.clone(),
                false => self.config.binary_implicit.clone()
            }
        );
        self.search_path(haystack.path())
    }

    /// Return a mutable reference to the underlying printer.
    pub(crate) fn printer(&mut self) -> &mut grep::printer::Standard<W> {
        &mut self.printer
    }

    /// Search the contents of the given file path.
    fn search_path(&mut self, path: &Path) -> io::Result<SearchResult> {
        use self::PatternMatcher::*;

            //println!("{:#?}", 1);
        let (searcher, printer) = (&mut self.searcher, &mut self.printer);
        match self.matcher {
            RustRegex(ref m) => search_path(m, searcher, printer, path),
            #[cfg(feature = "pcre2")]
            PCRE2(ref m) => search_path(m, searcher, printer, path),
                //for result in self.results_store.get_results().get_mut().iter_mut() {
                //    result.file_name = path.to_string_lossy().to_string();
                //}
                return self.results_store.has_match();
            },
            //#[cfg(feature = "pcre2")]
            //PCRE2(ref m) => search_path(m, searcher, results_store, path),
        }
    }
}

//Custom sink that doesn't use underlying printer instead keeps the vector of byte or converted string
#[derive(Debug)]
pub struct CustomSink {
    match_count: u64,
}

impl CustomSink {
    /// Returns true if and only if this sink received a match in the previous search
    pub fn has_match(&self) -> bool {
        self.match_count > 0
    }

    /// Return total number of stored to sink. Number of times `Sink::matched` called
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
        //println!("{:#?}", mat.bytes()); //Here
        //println!("{:#?}", mat.buffer()); //Raw file buf
        //println!("{:#?}", mat.bytes_range_in_buffer());
        self.match_count += 1;

        //Store match in buffer look to orginal : StandardImpl::from_match(searcher, self, mat).sink()?;
        Ok(true)
    }

    fn begin(&mut self, _searcher: &grep::searcher::Searcher) -> Result<bool, io::Error> {
        self.match_count = 0;
        return Ok(true);
    }
}

/// Search the contents of the given file path using the given matcher,
fn search_path<M: Matcher, W: WriteColor>(
    matcher: M,
    searcher: &mut grep::searcher::Searcher,
    printer: &mut grep::printer::Standard<W>,
    path: &Path,
) -> io::Result<SearchResult> {
    //println!("{:#?}", "StartSolutionHere");
    //I think the solution is here
    //I think the solution is here
    //I think the solution is here
    //
    //This is divergence of sink being whats written into to the sink being a child of printer
    //Returns mut sink but sink might be owned by printer and/or sink.matched() writes into printer
    let mut sink = printer.sink_with_path(&matcher, path);

    //println!("{:#?}", "BeforeSearchPath");
    searcher.search_path(&matcher, path, &mut sink)?;
    //println!("{:#?}", "AfterSearchPath");
    //println!("{:#?}", sink.bytes()); //So difficult consider it impossible
    return Ok(SearchResult { has_match: sink.has_match() })
}
