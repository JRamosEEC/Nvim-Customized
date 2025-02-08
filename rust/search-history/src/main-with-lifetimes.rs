#![allow(unused_imports)]
#![allow(unused_variables)]
#![allow(unused_assignments)]
#![allow(unused_mut)]
#![allow(dead_code)]

// Ripgrep source code project initialization below by default 64 bit musl 
// Re enable later if it doesn't break anything
//#[cfg(all(target_env = "musl", target_pointer_width = "64"))]
//#[global_allocator]
//static ALLOC: jemallocator::Jemalloc = jemallocator::Jemalloc;

use memory_stats::memory_stats;

use std::{sync::{Arc, Mutex}, collections::HashMap, io::Write, process::ExitCode};
use crate::{search::{SearchResult, SearchResults}, flags::{HiArgs, LowArgs, SearchMode}};

use ignore::WalkState;
use neovim_lib::{Neovim, NeovimApi, Session};

#[macro_use]
mod messages;
mod flags;
mod haystack;
mod logger;
mod search;

#[derive(Clone, Debug)]
pub(crate) struct TestSearchResult<'s> {
    //file_name: Option<&'s str>,
    file_name: String,
    line_number: u16, //If I could get like a u24 size wise that would make way more sense, maybe 3 u8's?
    matched_bytes: Vec<u8>,
    //This is two things I can try
    //matched_bytes: [u8; 50],
    //matched_bytes: ArrayVec<u8>,
}
impl<'s> TestSearchResult<'s> {
    pub(crate) fn new(file_name: Option<&'s str>, line_number: u16, matched_bytes: Vec<u8>) -> TestSearchResult<'s> {
        return TestSearchResult { file_name, line_number, matched_bytes };
    }
}

//This will have to store search results
#[derive(Debug, Clone)]
pub(crate) struct TestSearchResults<'s> {
    results_store: Vec<TestSearchResult<'s>>
}
impl<'s> TestSearchResults<'s> {
    pub(crate) fn new() -> TestSearchResults<'s> {
        return TestSearchResults { results_store: vec![] };
    }

    pub(crate) fn store_result(&mut self, search_result: TestSearchResult<'s>) {
        self.results_store.push(search_result);
    }

    pub(crate) fn get_mut(&mut self) -> &mut Vec<TestSearchResult<'s>> {
        return &mut self.results_store;
    }

    pub(crate) fn has_results(&self) -> bool {
        return self.results_store.len() > 0;
    }

    pub(crate) fn consume_results(self) -> Vec<TestSearchResult<'s>> {
        return self.results_store;
    }
}

#[derive(Debug)]
struct SearchStore<'s> {
    //search_store: HashMap<String, SearchResults>,
    search_store: HashMap<String, TestSearchResults<'s>>,
}

struct EventHandler {
    nvim: Neovim,
}
enum RpcMessages {
    Search,
    Query,
    Unknown(String),
}
impl From<String> for RpcMessages {
    fn from(event: String) -> Self {
        match &event[..] {
            "search" => RpcMessages::Search,
            _ => RpcMessages::Unknown(event),
        }
    }
}
impl EventHandler {
    fn new() -> EventHandler {
        let session = Session::new_parent().unwrap();
        let nvim = Neovim::new(session);
        return EventHandler { nvim };
    }

    //For now I'm not sure how better to handle unhappy path except return and end
    fn recv(&mut self) -> anyhow::Result<bool> {
        let mut search_store = SearchStore {
            search_store: HashMap::new()
        };

        //Get the initial low args (Inject search-positional in search call)
        let initial_args = match flags::parse_low(){
            crate::flags::ParseResult::Ok(low) => low,
            crate::flags::ParseResult::Err(err) => return Err(err),
            _ => return Ok(false),
        };

        let receiver = self.nvim.session.start_event_loop_channel();
        for (event, values) in receiver {
            match RpcMessages::from(event) {
                RpcMessages::Search => {
                    //let search_string: &str = values.iter().next().unwrap().as_str().unwrap();

                    let mut cloned_args = initial_args.clone();
                    cloned_args.positional.push(std::ffi::OsString::from("test")); //Term
                    cloned_args.positional.push(std::ffi::OsString::from("./")); //Dir
                    let hi_args_result = match crate::flags::HiArgs::from_low_args(cloned_args) {
                        Ok(hi_args) => crate::flags::ParseResult::Ok(hi_args),
                        Err(err) => crate::flags::ParseResult::Err(err),
                    };
                    let args = match hi_args_result{
                        crate::flags::ParseResult::Ok(args) => args,
                        crate::flags::ParseResult::Err(err) => return Err(err),
                        _ => return Ok(false),
                    };

                    match rg_search(&args) {
                        Ok(search_results) => {
                            search_store.search_store.insert(String::from("Test-Search"), search_results);
                        },
                        Err(err) => eprintln_locked!("{:#}", err), 
                    };
                    //let mut file = std::fs::File::create("testargs.txt")?; //writeln!(&mut file, "{:#?}", args)?;
                    //eprintln_locked!("{:#?}", std::env::current_dir()); //Better way of print debugging - stderr
                }
                RpcMessages::Query => {
                    let search_string: u64 = values.iter().next().unwrap().as_u64().unwrap();
                }
                RpcMessages::Unknown(event) => {
                    self.nvim.command("echo \"test\"").unwrap();
                    //Unknown Event
                }
            }
        }
        return Ok(true);
    }
}

fn main() -> ExitCode {
    let mut debug_mode: bool = false;
    let args: Vec<String> = std::env::args().collect();
    for arg in args {
        if arg.as_str() == "debug" {
            debug_mode = true;
        }
    }
    if debug_mode {
        let mut search_store = SearchStore {
            search_store: HashMap::new()
        };

        //Get the initial low args (Inject search-positional in search call)
        let initial_args = match flags::parse_low(){
            crate::flags::ParseResult::Ok(low) => low,
            crate::flags::ParseResult::Err(err) => return ExitCode::FAILURE,
            _ => return ExitCode::FAILURE,
        };

        let mut cloned_args = initial_args.clone();
        cloned_args.positional.pop(); //Pop off the debug (Should be first)
        //Tests implicit
        cloned_args.positional.push(std::ffi::OsString::from("a")); //Term
        //cloned_args.positional.push(std::ffi::OsString::from("test.*t")); //Term
        cloned_args.positional.push(std::ffi::OsString::from("./")); //Dir
        //Tests eplicit
        //cloned_args.positional.push(std::ffi::OsString::from("alphanu")); //Term
        //cloned_args.positional.push(std::ffi::OsString::from("./src/flags/defs.rs")); //Dir
        let hi_args_result = match crate::flags::HiArgs::from_low_args(cloned_args) {
            Ok(hi_args) => crate::flags::ParseResult::Ok(hi_args),
            Err(err) => crate::flags::ParseResult::Err(err),
        };
        let args = match hi_args_result{
            crate::flags::ParseResult::Ok(args) => args,
            crate::flags::ParseResult::Err(err) => return ExitCode::FAILURE,
            _ => return ExitCode::FAILURE,
        };
                    //let mut file = std::fs::File::create("testargs2.txt").unwrap();
                    //writeln!(&mut file, "{:#?}", args).unwrap();
        let search_results = match rg_search(&args) {
            Ok(search_results) => search_results,
            Err(err) => {
                eprintln_locked!("{:#}", err);
                return ExitCode::FAILURE;
            }, 
        };
        //search_store.search_store.insert(String::from("Test-Search"), search_results);
        //println!("{:#?}", search_store);

        if let Some(usage) = memory_stats() {
            println!("Current physical memory usage: {}", usage.physical_mem);
            println!("Current virtual memory usage: {}", usage.virtual_mem);
        } else {
            println!("Couldn't get the current memory usage :(");
        }
        return ExitCode::SUCCESS;
    }

    let mut event_handler = EventHandler::new();
    match event_handler.recv() {
        Ok(res) => (),
        Err(err) => {
            for cause in err.chain() {
                if let Some(ioerr) = cause.downcast_ref::<std::io::Error>() {
                    if ioerr.kind() == std::io::ErrorKind::BrokenPipe {
                        return ExitCode::SUCCESS;
                    }
                }
            }
            eprintln_locked!("{:#}", err);
            return ExitCode::FAILURE;
        }
    };
    return ExitCode::SUCCESS;

    //Easier debugging for when converting to array return
    //match rg(flags::parse()) {
    //    Ok(res) => return ExitCode::SUCCESS,
    //    Err(err) => return ExitCode::FAILURE
    //};

    //Plan of attack
    //Example of the ParseResult HiArgs returned from parse
    //pub(crate) fn parse() -> ParseResult<HiArgs> {
    //    parse_low().and_then(|low| match HiArgs::from_low_args(low) {
    //        Ok(hi) => ParseResult::Ok(hi),
    //        Err(err) => ParseResult::Err(err),
    //    })
    //}

    //--Raw diff
    //positional: [], => positional: ["test"], --This one obviously gets passed in (The dir is default ./ but I could pass in dir as well)
    //case: Sensitive, => case: Smart,
    //color: Auto, => color: Never,
    //column: None, => column: Some(true),
    //globs: [], => globs: [
    //    "!*.min.{js, ss, s.map, ss.map}",
    //    "!public/js/jquery*",
    //    "!wordpress/wp-includes/*",
    //    "!wordpress/wp-admin/*", 
    //    "!wordpress/wp-content/plugins/*",
    //    "!migrations/*/seeds/*"
    //],
    //heading: None, => heading: Some(false),
    //hidden: false, => hidden: true,
    //line_number: None, => line_number: Some(true),
    //max_filesize: None, => max_filesize: Some(302080),
    //no_ignore_dot: false, => no_ignore_dot: true,
    //no_ignore_exclude: false, => no_ignore_exclude: true,
    //no_ignore_global: false, => no_ignore_global: true,
    //no_ignore_parent: false, => no_ignore_parent: true,
    //no_ignore_vcs: false, => no_ignore_vcs: true,
    //only_matching: false, => only_matching: true,
    //unrestricted: 0, => unrestricted: 2,
    //vimgrep: false, => vimgrep: true,
    //with_filename: None => with_filename: Some(true)
    //

    //let mut low = LowArgs::default();
    //low.positional.push(std::ffi::OsString::from("test"));
    ////low.color = crate::flags::ColorChoice::Never;
    //let hi = match HiArgs::from_low_args(low) {
    //    Ok(hi) => crate::flags::ParseResult::Ok(hi),
    //    Err(err) => crate::flags::ParseResult::Err(err),
    //};
    //match run_search(hi) {

    //match run_search(flags::parse()) {
}

fn rg_search<'s>(args: &crate::flags::HiArgs) -> anyhow::Result<TestSearchResults<'s>> {
    let search_results = match args.matches_possible() {
        true => search_parallel(&args),
        _ => return Err(anyhow::anyhow!("No results found")),
    };
    let search_results = match search_results {
        Ok(search_results) => search_results,
        Err(err) => return Err(err),
    };

    if search_results.has_results() {
        return Ok(search_results);
    }
    return Err(anyhow::anyhow!("No results found"));
}

fn search_parallel<'s>(args: &crate::flags::HiArgs) -> anyhow::Result<TestSearchResults<'s>> {
    let haystack_builder = args.haystack_builder();
    let bufwtr = args.buffer_writer();

    // (This is likely way beyond my skillset to do efficiently I'd have to rewrite all the search algorithms)
    //I might have to start with an Arc<Mutex<SearchResults>> and try to rewrite multi-threading to return values
    //let search_results = Arc<Mutex<SearchResults::new()>>;
    let mut threaded_search_results = Arc::new(Mutex::new(TestSearchResults::new()));
    let mut searcher = args.search_worker(
        args.matcher()?,
        args.searcher()?,
    )?;

    args.walk_builder()?.build_parallel().run(|| {
        let bufwtr = &bufwtr;
        let haystack_builder = &haystack_builder;

        /*
        * I'm working on a few things at once
        * One Id like to consume_results to remove .clone() & return ownership then compare performance
        * Also trying use fixed length buffer matched bytes, see if time save with paging, compare performance
        * Lastly I'm separating thread search result structs from regular one to separate storing
        * the &str from path using haystack.path() -> Path then Path.to_str() -> Option<&str>
        */


        //let mut searcher = &searcher; //Can I use a refence does this need to clone?
        let mut searcher = searcher.clone(); //Can I use a refence does this need to clone?
        let mut threaded_search_results = &threaded_search_results;

        return Box::new(move |result| {
            let mut threaded_search_results = threaded_search_results.lock().unwrap();

            let haystack = match haystack_builder.build_from_result(result) {
                Some(haystack) => haystack,
                None => return WalkState::Continue,
            };

            //Push to outer search results vector
            //let path = haystack.path().to_str();
            if searcher.search(&haystack) {
                //for search_result in searcher.consume_searcher_results().consume_results().iter_mut() {
                for search_result in searcher.get_results().get_mut().iter_mut() {
                    //search_result.set_file_name(Some(haystack.path().to_string_lossy().to_string()));
                    //search_result.set_file_name(Some(haystack.path().to_str()));
                    threaded_search_results.store_result(TestSearchResult {
                        file_name: Some(haystack.path().to_string_lossy().to_string()),
                        line_number: search_result.get_line_number(),
                        matched_bytes: search_result.get_matched_bytes().clone(),
                    });
                }
            }
            return WalkState::Continue;
        });
    });

    let mutex_search_results = match Arc::into_inner(threaded_search_results) {
        Some(mutex_results) => mutex_results,
        None => return Err(anyhow::anyhow!("Could not unwrap Mutex from Arc")),
    };
    return match mutex_search_results.into_inner() {
        Ok(search_results) => Ok(search_results),
        Err(err) => Err(err.into()),
    };
}

//Might want to see this syntax later
//let result_strs: Vec<RawResult> = values
//    .into_iter()
//    .map(|v| RawResult{grep_result: v.to_string()})
//    .collect();
