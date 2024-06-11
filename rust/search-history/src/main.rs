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


/// This is the big test can I write my own Buffer
/// I'm not sure how this will work surely the color information comes from checking the enum from
/// term color (Probably need to modify more rg modules)
//#[derive(Clone, Debug)]
//pub struct NoColor<W>(W);
//
//impl<W: Write> NoColor<W> {
//    //Note the wtr here is the Vec<u8> (That's the buffer)
//    pub fn new(wtr: W) -> NoColor<W> {
//        NoColor(wtr)
//    }
//
//    /// Consume this `NoColor` value and return the inner writer.
//    pub fn into_inner(self) -> W {
//        self.0
//    }
//
//    /// Return a reference to the inner writer.
//    pub fn get_ref(&self) -> &W {
//        &self.0
//    }
//
//    /// Return a mutable reference to the inner writer.
//    pub fn get_mut(&mut self) -> &mut W {
//        &mut self.0
//    }
//}
//
//impl<W: Write> Write for NoColor<W> {
//    #[inline]
//    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
//        self.0.write(buf)
//    }
//
//    #[inline]
//    fn flush(&mut self) -> std::io::Result<()> {
//        self.0.flush()
//    }
//}
//
//impl<W: Write> termcolor::WriteColor for NoColor<W> {
//    #[inline]
//    fn supports_color(&self) -> bool {
//        false
//    }
//
//    #[inline]
//    fn supports_hyperlinks(&self) -> bool {
//        false
//    }
//
//    #[inline]
//    fn set_color(&mut self, _: &termcolor::ColorSpec) -> std::io::Result<()> {
//        Ok(())
//    }
//
//    #[inline]
//    fn set_hyperlink(&mut self, _: &termcolor::HyperlinkSpec) -> std::io::Result<()> {
//        Ok(())
//    }
//
//    #[inline]
//    fn reset(&mut self) -> std::io::Result<()> {
//        Ok(())
//    }
//
//    #[inline]
//    fn is_synchronous(&self) -> bool {
//        false
//    }
//}


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
        return EventHandler { nvim };
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

                    //Will have to send the search
                    //self.nvim.command("echo \"test\"").unwrap();
                    //self.nvim.command(&format!("echo \"{:?}\"", receiver)).unwrap();
                    self.nvim.command("echo 'Starting Test'").unwrap();
                    self.nvim.command("echo 'Run:'").unwrap();
                    let result = match rg_search(&args) {
                        Ok(res) => true,
                        Err(err) => return Err(err), 
                    };
                    self.nvim.command("echo '-Finish'").unwrap();
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
        //Get the initial low args (Inject search-positional in search call)
        let initial_args = match flags::parse_low(){
            crate::flags::ParseResult::Ok(low) => low,
            crate::flags::ParseResult::Err(err) => return ExitCode::FAILURE,
            _ => return ExitCode::FAILURE,
        };

        let mut cloned_args = initial_args.clone();
        cloned_args.positional.pop(); //Pop off the debug (Should be first)
        //cloned_args.positional.push(std::ffi::OsString::from("test.*t")); //Term
        //Tests implicit
        cloned_args.positional.push(std::ffi::OsString::from("l.l")); //Term
        cloned_args.positional.push(std::ffi::OsString::from("./src/")); //Dir
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
        let result = match rg_search(&args) {
            Ok(res) => true,
            Err(err) => {
                eprintln_locked!("{:#}", err);
                return ExitCode::FAILURE;
            }, 
        };
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

fn rg_search(args: &crate::flags::HiArgs) -> anyhow::Result<bool> {
    let matched = match args.mode() {
        crate::flags::Mode::Search(_) if !args.matches_possible() => false,
        crate::flags::Mode::Search(mode) => search_parallel(&args, mode)?,
        _ => return Ok(false),
    };
    if matched && (args.quiet() || !messages::errored()) {
        return Ok(true);
    }
    return Ok(false);
}

fn search_parallel(args: &crate::flags::HiArgs, mode: SearchMode) -> anyhow::Result<bool> {
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
    let mut searcher = args.search_worker(
        args.matcher()?,
        args.searcher()?,
        args.printer(bufwtr.buffer()), //test_vec_as_buf, //args.printer(mode, test_buffer), //This is doable
    )?;
            //println!("{:#?}", "After Create Search Worker");
    args.walk_builder()?.build_parallel().run(|| {
        let bufwtr = &bufwtr;
        let haystack_builder = &haystack_builder;
        let mut searcher = searcher.clone();

        Box::new(move |result| {
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
            }
            //return WalkState::Quit;
            return WalkState::Continue;
        })
    });
    return Ok(true);
}

//Might want to see this syntax later
//let result_strs: Vec<RawResult> = values
//    .into_iter()
//    .map(|v| RawResult{grep_result: v.to_string()})
//    .collect();
