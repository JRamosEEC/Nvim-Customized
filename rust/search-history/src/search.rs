/*!
Defines a very high level "search worker" abstraction.

A search worker manages the high level interaction points between the matcher
(i.e., which regex engine is used), the searcher (i.e., how data is actually
read and matched using the regex engine) and the printer. For example, the
search worker is where things like preprocessors or decompression happens.
*/

use std::{io, path::Path};

use {bstr::ByteVec, grep::matcher::Matcher, termcolor::WriteColor};

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
