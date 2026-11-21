//! The connetto-schema SQL, read from the checkout this crate is built in.
//!
//! [`bootstrap()`] is `cluster/roles.sql`, [`slices()`] every `up.sql` under
//! `sql/` in the order `tests/run.sh` applies them, and [`schema()`] both.

use std::{fs, io, path::Path};

/// The repository directory holding `cluster/` and `sql/`.
///
/// # Panics
///
/// Panics if the crate manifest has no parent directory, which a checkout
/// of this repository always has.
#[must_use]
pub fn root() -> &'static Path {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("repository root")
}

/// The cluster bootstrap in `cluster/roles.sql`.
///
/// # Errors
///
/// Returns the error reading `cluster/roles.sql`.
pub fn bootstrap() -> io::Result<String> {
    fs::read_to_string(root().join("cluster/roles.sql"))
}

/// The `up.sql` files of the slice directories under `sql/`, each after a
/// newline, in their application order.
///
/// # Errors
///
/// Returns the error of the first directory or file that cannot be read.
pub fn slices() -> io::Result<String> {
    let mut paths = fs::read_dir(root().join("sql"))?
        .map(|entry| entry.map(|entry| entry.path().join("up.sql")))
        .collect::<io::Result<Vec<_>>>()?;
    paths.sort();
    let mut slices = String::new();
    for path in paths {
        slices.push('\n');
        slices.push_str(&fs::read_to_string(path)?);
    }
    Ok(slices)
}

/// The cluster bootstrap followed by every slice.
///
/// # Errors
///
/// Returns the error of the first file that cannot be read.
pub fn schema() -> io::Result<String> {
    Ok(bootstrap()? + &slices()?)
}
