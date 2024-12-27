use clap::{Arg, Command};
use std::{
    path::PathBuf,
    process::Command as ProcessCommand,
    thread,
    time::Duration,
    collections::HashSet,
};

#[derive(Debug)]
struct Config {
    directories: Vec<PathBuf>,
    reload_command: String,
    check_interval: u64,
    mode: TriggerMode,
    stop_after: bool,
}

#[derive(Debug, Clone, PartialEq)]
enum TriggerMode {
    Any,
    All,
}

impl std::str::FromStr for TriggerMode {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "any" => Ok(TriggerMode::Any),
            "all" => Ok(TriggerMode::All),
            _ => Err(format!("Invalid mode: {}. Must be 'any' or 'all'", s)),
        }
    }
}

fn parse_args() -> Config {
    let matches = Command::new("directory-monitor")
        .version("1.0")
        .author("Directory Monitor")
        .about("Monitors directories and executes a command when they disappear")
        .arg(
            Arg::new("directories")
                .short('d')
                .long("dir")
                .action(clap::ArgAction::Append)
                .required(true)
                .help("Directories to monitor (can be specified multiple times)"),
        )
        .arg(
            Arg::new("command")
                .short('c')
                .long("command")
                .required(true)
                .help("Command to execute when directory/directories disappear"),
        )
        .arg(
            Arg::new("stop-after")
                .default_value("false")
                .long("stop-after")
                .value_parser(clap::value_parser!(bool))
                .required(false)
                .help("Stop after running the command")
        )
        .arg(
            Arg::new("interval")
                .short('i')
                .long("interval")
                .default_value("5")
                .value_parser(clap::value_parser!(u64))
                .help("Check interval in seconds"),
        )
        .arg(
            Arg::new("mode")
                .short('m')
                .long("mode")
                .default_value("any")
                .value_parser(["any", "all"])
                .help("Trigger mode: 'any' or 'all'"),
        )
        .get_matches();

    let directories: Vec<PathBuf> = matches
        .get_many::<String>("directories")
        .unwrap()
        .map(|s| PathBuf::from(s))
        .collect();

    let reload_command = matches.get_one::<String>("command").unwrap().clone();
    let check_interval = *matches.get_one::<u64>("interval").unwrap();
    let mode = matches.get_one::<String>("mode").unwrap().parse().unwrap();
    let stop_after = matches.get_one::<bool>("stop-after").unwrap().clone();

    Config {
        directories,
        reload_command,
        check_interval,
        mode,
        stop_after,
    }
}

fn validate_directories(directories: &[PathBuf]) -> Result<(), String> {
    for dir in directories {
        if !dir.exists() || !dir.is_dir() {
            return Err(format!("Directory does not exist: {}", dir.display()));
        }
    }
    Ok(())
}

fn check_directories(config: &Config) -> Option<HashSet<PathBuf>> {
    let mut missing = HashSet::new();

    for dir in &config.directories {
        if !dir.exists() || !dir.is_dir() {
            missing.insert(dir.clone());
        }
    }

    match config.mode {
        TriggerMode::Any if !missing.is_empty() => Some(missing),
        TriggerMode::All if missing.len() == config.directories.len() => Some(missing),
        _ => None,
    }
}

fn execute_command(command: &str) -> Result<(), String> {
    let parts: Vec<&str> = command.split_whitespace().collect();
    if parts.is_empty() {
        return Err("Empty command".to_string());
    }

    let status = ProcessCommand::new(parts[0])
        .args(&parts[1..])
        .status()
        .map_err(|e| format!("Failed to execute command: {}", e))?;

    if !status.success() {
        return Err(format!("Command failed with exit code: {}", status));
    }

    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = parse_args();

    // Validate directories exist at start
    validate_directories(&config.directories)?;

    println!("Starting directory monitor with mode: {:?}", config.mode);
    println!("Directories being monitored:");
    for dir in &config.directories {
        println!("  {}", dir.display());
    }
    println!("Will execute: {}", config.reload_command);
    println!("Checking every {} seconds", config.check_interval);

    loop {
        if let Some(missing_dirs) = check_directories(&config) {
            println!("\nMissing directories detected at {}:",
                    chrono::Local::now().format("%Y-%m-%d %H:%M:%S"));
            for dir in missing_dirs {
                println!("  {}", dir.display());
            }

            println!("Executing reload command: {}", config.reload_command);
            if let Err(e) = execute_command(&config.reload_command) {
                eprintln!("Error executing command: {}", e);
                return Err(e.into());
            }
            if config.stop_after {
                break;
            }
        }

        thread::sleep(Duration::from_secs(config.check_interval));
    }

    Ok(())
}
