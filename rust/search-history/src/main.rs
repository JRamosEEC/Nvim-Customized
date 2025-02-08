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

//From pulled changes
//use std::{io::Write, process::ExitCode};
//use crate::flags::{HiArgs, LowArgs, SearchMode};

//From local
use memory_stats::memory_stats;

use std::{sync::{Arc, Mutex}, collections::HashMap, io::Write, process::ExitCode};
use crate::{search::{SearchResult, SearchResults}, flags::{HiArgs, LowArgs, SearchMode}};
// End conflict

use ignore::WalkState;
use neovim_lib::{Neovim, NeovimApi, Session};

#[macro_use]
mod messages;
mod flags;
mod haystack;
mod logger;
mod search;

#[derive(Debug)]
struct SearchStore {
    search_store: HashMap<String, SearchResults>,
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

fn rg_search(args: &crate::flags::HiArgs) -> anyhow::Result<SearchResults> {
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

fn search_parallel(args: &crate::flags::HiArgs) -> anyhow::Result<SearchResults> {
    let haystack_builder = args.haystack_builder();
    let bufwtr = args.buffer_writer();

    //Actually I just realized my options right now have a color writer that's not correct
    //This however forces no color
    let test_buffer = termcolor::Buffer::no_color(); //Termcolor buffer_writer().buffer();
        //println!("{:#?}", bufwtr.color_choice);
        //test_buffer.write_all("test");

    //let test_vec_as_buf = vec![];
    //let test_printer_with_vec = search::Printer::Standard(self.printer_standard(wtr));

            //println!("{:#?}", "Create Search Worker");
    //Have to rewrite this to not use a printer at all
    //Everything depends on W being a termcolor::WriteColor generic


    //Next step is to completely remove the printer and work with the sole buffers
    //Search worker will manage the buffer and it will create a CustomSink
    //SearchWorker likely need to store buffer of buffers & create  single use buffer for each thread
    //This custom sink will implement the ability to Vec<u8> buffers.push() it's buffer of matched bytes
    //Custom sink will also need to get that line number and store it somehow
    // (This is likely way beyond my skillset to do efficiently I'd have to rewrite all the search algorithms)
    //I might have to start with an Arc<Mutex<SearchResults>> and try to rewrite multi-threading to return values
    //let search_results = Arc<Mutex<SearchResults::new()>>;
    let mut threaded_search_results = Arc::new(Mutex::new(SearchResults::new()));

    let mut searcher = args.search_worker(
        args.matcher()?,
        args.searcher()?,
        args.printer(bufwtr.buffer()), //test_vec_as_buf, //args.printer(mode, test_buffer), //This is doable
    )?;

            //println!("{:#?}", "After Create Search Worker");
=======

>>>>>>> Stashed changes
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
            searcher.printer().get_mut().clear();
            let search_result = match searcher.search(&haystack) {
                Ok(search_result) => search_result,
                Err(err) => {
                    err_message!("{}: {}", haystack.path().display(), err);
                    return WalkState::Continue;
                }
            };
            //The wtr stored in the print is some how populated with the raw output buffer
            //This includes the desired results for linenum & preview line
            //Unlike the state of sink in core.rs this is a joined buffer
            //If I can somehow get the raw line by line that gets matched to sink and just store
            //Each line in a vector that would be ideal, though I can split raw buffer just as easily
            //I believe this will have something to do with bufwtr and the buffer()
            //That printer is constructed with as that is the wtr it's writing to
            //It'll be tough but I might be able to create a custom buffer that will write to a
            //Vector index for each line
            //println!("{:#?}", searcher.printer().get_mut()); //I believe this is the buffer

            //haystack.path() - With this I can store the path
            //
            //sunk.line_number() //Somehow I have to get the line number out of the sunk
            // -Look to this (standard.rs)
            // -- Sunk is created with SinkMatch where SinkMatch.line_number()
            // -- SinkMatch is passed in to matched as param so CustomSink should get this
            //
            //fn from_match(
            //    searcher: &'a Searcher,
            //    sink: &'a StandardSink<'_, '_, M, W>,
            //    mat: &'a SinkMatch<'a>,
            //) -> StandardImpl<'a, M, W> {
            //    let sunk = Sunk::from_sink_match(
            //        mat,
            //        &sink.standard.matches,
            //        sink.replacer.replacement(),
            //    );
            //    StandardImpl { sunk, ..StandardImpl::new(searcher, sink) }
            //}
            //
            if let Err(err) = bufwtr.print(searcher.printer().get_mut()) {
                if err.kind() == std::io::ErrorKind::BrokenPipe {
                    return WalkState::Quit; //Broken pipe means graceful termination.
                }
                err_message!("{}: {}", haystack.path().display(), err);
            //Push to outer search results vector
            //let path = Some(haystack.path().to_string_lossy().to_string());
            let path = haystack.path().as_os_str();
            if searcher.search(&haystack) {
                //for search_result in searcher.consume_searcher_results().consume_results().iter_mut() {
                for search_result in searcher.get_results().get_mut().iter_mut() {
                    search_result.set_file_name(Some(path.to_str().clone()));
                    //search_result.set_file_name(Some(haystack.path().to_str()));
                    threaded_search_results.store_result(search_result.clone());
                }
            }
            //return WalkState::Quit;
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
