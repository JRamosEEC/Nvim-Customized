#![allow(unused_imports)]
#![allow(unused_variables)]
#![allow(dead_code)]

// Ripgrep source code project initialization below by default 64 bit musl 
#[cfg(all(target_env = "musl", target_pointer_width = "64"))]
#[global_allocator]
static ALLOC: jemallocator::Jemalloc = jemallocator::Jemalloc;

use std::{io::Write, process::ExitCode};
use crate::flags::{HiArgs, LowArgs, SearchMode};

use ignore::WalkState;
use neovim_lib::{Neovim, NeovimApi, Session};

#[macro_use]
mod messages;
mod flags;
mod haystack;
mod logger;
mod search;


//use grep::{cli, matcher, printer, regex, searcher};
//extern crate ripgrep;
//use ripgrep;

struct GrepProccess {
    //I'm not sure this will need any properties
}
impl GrepProccess {

}

struct RawResult {
    grep_result: String,
}
impl RawResult {
    //Create a processed result
}

struct ProccessedResult {
    file_name: String,
    line_num: u16,
    column_num: u16,
    preview_text: String,
}

struct EventHandler {
    nvim: Neovim,
}
enum RpcMessages {
    Search,
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

        EventHandler { nvim }
    }

    //For now I'm not sure how better to handle unhappy path except return and end
    fn recv(&mut self) -> anyhow::Result<bool> {
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
                    let search_string: &str = values.iter().next().unwrap().as_str().unwrap();

                    let mut cloned_args = initial_args.clone();
                    cloned_args.positional.push(std::ffi::OsString::from("test"));
                    let hi_args_result = match crate::flags::HiArgs::from_low_args(cloned_args) {
                        Ok(hi_args) => crate::flags::ParseResult::Ok(hi_args),
                        Err(err) => crate::flags::ParseResult::Err(err),
                    };
                    let args = match hi_args_result{
                        crate::flags::ParseResult::Ok(args) => args,
                        crate::flags::ParseResult::Err(err) => return Err(err),
                        _ => return Ok(false),
                    };

                    //Will have to send the search
                    //self.nvim.command(format!("echo \"{}\"", search_string).as_str()).unwrap();
                    self.nvim.command("echo 'Starting Test'").unwrap();
                    self.nvim.command("echo 'Run:'").unwrap();
                    let result = match rg_search(&args) {
                        Ok(res) => true,
                        Err(err) => false, 
                    };
                    self.nvim.command("echo '-Finish'").unwrap();
                }
                RpcMessages::Unknown(event) => {
                    //Unknown Event
                }
            }
        }
        return Ok(true);
    }
}

fn main() -> ExitCode {
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

fn rg_search(args: &crate::flags::HiArgs) -> anyhow::Result<bool> {
    let matched = match args.mode() {
        crate::flags::Mode::Search(_) if !args.matches_possible() => false,
        crate::flags::Mode::Search(mode) => search_parallel(&args, mode)?,
        crate::flags::Mode::Files => files_parallel(&args)?,
        _ => return Ok(false),
    };
    if matched && (args.quiet() || !messages::errored()) {
        return Ok(true);
    }
    return Ok(false);
}

fn search_parallel(args: &crate::flags::HiArgs, mode: SearchMode) -> anyhow::Result<bool> {
    use std::sync::atomic::{AtomicBool, Ordering};

    let started_at = std::time::Instant::now();
    let haystack_builder = args.haystack_builder();
    let bufwtr = args.buffer_writer();
    let stats = args.stats().map(std::sync::Mutex::new);
    let matched = AtomicBool::new(false);
    let searched = AtomicBool::new(false);

    let mut searcher = args.search_worker(
        args.matcher()?,
        args.searcher()?,
        args.printer(mode, bufwtr.buffer()),
    )?;
    args.walk_builder()?.build_parallel().run(|| {
        let bufwtr = &bufwtr;
        let stats = &stats;
        let matched = &matched;
        let searched = &searched;
        let haystack_builder = &haystack_builder;
        let mut searcher = searcher.clone();

        Box::new(move |result| {
            let haystack = match haystack_builder.build_from_result(result) {
                Some(haystack) => haystack,
                None => return WalkState::Continue,
            };
            searched.store(true, Ordering::SeqCst);
            searcher.printer().get_mut().clear();
            let search_result = match searcher.search(&haystack) {
                Ok(search_result) => search_result,
                Err(err) => {
                    err_message!("{}: {}", haystack.path().display(), err);
                    return WalkState::Continue;
                }
            };
            if search_result.has_match() {
                matched.store(true, Ordering::SeqCst);
            }
            if let Some(ref locked_stats) = *stats {
                let mut stats = locked_stats.lock().unwrap();
                *stats += search_result.stats().unwrap();
            }
            if let Err(err) = bufwtr.print(searcher.printer().get_mut()) {
                // A broken pipe means graceful termination.
                if err.kind() == std::io::ErrorKind::BrokenPipe {
                    return WalkState::Quit;
                }
                // Otherwise, we continue on our merry way.
                err_message!("{}: {}", haystack.path().display(), err);
            }
            if matched.load(Ordering::SeqCst) && args.quit_after_match() {
                WalkState::Quit
            } else {
                WalkState::Continue
            }
        })
    });
    if args.has_implicit_path() && !searched.load(Ordering::SeqCst) {
        eprint_nothing_searched();
    }
    if let Some(ref locked_stats) = stats {
        let stats = locked_stats.lock().unwrap();
        let mut wtr = searcher.printer().get_mut();
        let _ = print_stats(mode, &stats, started_at, &mut wtr);
        let _ = bufwtr.print(&mut wtr);
    }
    Ok(matched.load(Ordering::SeqCst))
}

/// This recursively steps through the file list (current directory by default)
/// and prints each path sequentially using multiple threads.
fn files_parallel(args: &HiArgs) -> anyhow::Result<bool> {
    use std::{
        sync::{
            atomic::{AtomicBool, Ordering},
            mpsc,
        },
        thread,
    };

    let haystack_builder = args.haystack_builder();
    let mut path_printer = args.path_printer_builder().build(args.stdout());
    let matched = AtomicBool::new(false);
    let (tx, rx) = mpsc::channel::<crate::haystack::Haystack>();

    // We spawn a single printing thread to make sure we don't tear writes.
    // We use a channel here under the presumption that it's probably faster
    // than using a mutex in the worker threads below, but this has never been
    // seriously litigated.
    let print_thread = thread::spawn(move || -> std::io::Result<()> {
        for haystack in rx.iter() {
            path_printer.write(haystack.path())?;
        }
        Ok(())
    });
    args.walk_builder()?.build_parallel().run(|| {
        let haystack_builder = &haystack_builder;
        let matched = &matched;
        let tx = tx.clone();

        Box::new(move |result| {
            let haystack = match haystack_builder.build_from_result(result) {
                Some(haystack) => haystack,
                None => return WalkState::Continue,
            };
            matched.store(true, Ordering::SeqCst);
            if args.quit_after_match() {
                WalkState::Quit
            } else {
                match tx.send(haystack) {
                    Ok(_) => WalkState::Continue,
                    Err(_) => WalkState::Quit,
                }
            }
        })
    });
    drop(tx);
    if let Err(err) = print_thread.join().unwrap() {
        // A broken pipe means graceful termination, so fall through.
        // Otherwise, something bad happened while writing to stdout, so bubble
        // it up.
        if err.kind() != std::io::ErrorKind::BrokenPipe {
            return Err(err.into());
        }
    }
    Ok(matched.load(Ordering::SeqCst))
}

fn eprint_nothing_searched() {
    err_message!(
        "No files were searched, which means ripgrep probably \
         applied a filter you didn't expect.\n\
         Running with --debug will show why files are being skipped."
    );
}

//See if even runs. ideally remove any bloat like useless printing. I just want data strucutre
fn print_stats<W: Write>(
    mode: SearchMode,
    stats: &grep::printer::Stats,
    started: std::time::Instant,
    mut wtr: W,
) -> std::io::Result<()> {
    let elapsed = std::time::Instant::now().duration_since(started);
    if matches!(mode, SearchMode::JSON) {
        // We specifically match the format laid out by the JSON printer in
        // the grep-printer crate. We simply "extend" it with the 'summary'
        // message type.
        serde_json::to_writer(
            &mut wtr,
            &serde_json::json!({
                "type": "summary",
                "data": {
                    "stats": stats,
                    "elapsed_total": {
                        "secs": elapsed.as_secs(),
                        "nanos": elapsed.subsec_nanos(),
                        "human": format!("{:0.6}s", elapsed.as_secs_f64()),
                    },
                }
            }),
        )?;
        write!(wtr, "\n")
    } else {
        write!(
            wtr,
            "
{matches} matches
{lines} matched lines
{searches_with_match} files contained matches
{searches} files searched
{bytes_printed} bytes printed
{bytes_searched} bytes searched
{search_time:0.6} seconds spent searching
{process_time:0.6} seconds
",
            matches = stats.matches(),
            lines = stats.matched_lines(),
            searches_with_match = stats.searches_with_match(),
            searches = stats.searches(),
            bytes_printed = stats.bytes_printed(),
            bytes_searched = stats.bytes_searched(),
            search_time = stats.elapsed().as_secs_f64(),
            process_time = elapsed.as_secs_f64(),
        )
    }
}

//Might want to see this syntax later
//let result_strs: Vec<RawResult> = values
//    .into_iter()
//    .map(|v| RawResult{grep_result: v.to_string()})
//    .collect();
