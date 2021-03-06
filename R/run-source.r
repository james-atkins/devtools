#' Run a script through some protocols such as http, https, ftp, etc.
#'
#' If a SHA-1 hash is specified with the \code{sha1} argument, then this
#' function will check the SHA-1 hash of the downloaded file to make sure it
#' matches the expected value, and throw an error if it does not match. If the
#' SHA-1 hash is not specified, it will print a message displaying the hash of
#' the downloaded file. The purpose of this is to improve security when running
#' remotely-hosted code; if you have a hash of the file, you can be sure that
#' it has not changed. For convenience, it is possible to use a truncated SHA1
#' hash, down to 6 characters, but keep in mind that a truncated hash won't be
#' as secure as the full hash.
#'
#' @param url url
#' @param ... other options passed to \code{\link{source}}
#' @param sha1 The (prefix of the) SHA-1 hash of the file at the remote URL.
#' @export
#' @examples
#' \dontrun{
#'
#' source_url("https://gist.github.com/hadley/6872663/raw/hi.r")
#'
#' # With a hash, to make sure the remote file hasn't changed
#' source_url("https://gist.github.com/hadley/6872663/raw/hi.r",
#'   sha1 = "54f1db27e60bb7e0486d785604909b49e8fef9f9")
#'
#' # With a truncated hash
#' source_url("https://gist.github.com/hadley/6872663/raw/hi.r",
#'   sha1 = "54f1db27e60")
#' }
source_url <- function(url, ..., sha1 = NULL) {
  stopifnot(is.character(url), length(url) == 1)

  temp_file <- tempfile()
  on.exit(unlink(temp_file))

  request <- httr::GET(url)
  httr::stop_for_status(request)
  writeBin(httr::content(request, type = "raw"), temp_file)

  file_sha1 <- digest::digest(file = temp_file, algo = "sha1")

  if (is.null(sha1)) {
    message("SHA-1 hash of file is ", file_sha1)
  } else {
    if (nchar(sha1) < 6) {
      stop("Supplied SHA-1 hash is too short (must be at least 6 characters)")
    }

    # Truncate file_sha1 to length of sha1
    file_sha1 <- substr(file_sha1, 1, nchar(sha1))

    if (!identical(file_sha1, sha1)) {
      stop("SHA-1 hash of downloaded file (", file_sha1,
           ")\n  does not match expected value (", sha1, ")", call. = FALSE)
    }
  }

  source(temp_file, ...)
}

#' Run a script on gist
#'
#' \dQuote{Gist is a simple way to share snippets and pastes with others.
#'   All gists are git repositories, so they are automatically versioned,
#'   forkable and usable as a git repository.}
#' \url{https://gist.github.com/}
#'
#' @param id either full url (character), gist ID (numeric or character of
#'   numeric).
#' @param ... other options passed to \code{\link{source}}
#' @param filename if there is more than one R file in the gist, which one to
#' source (filename ending in '.R')? Default \code{NULL} will source the
#' first file.
#' @param sha1 The SHA-1 hash of the file at the remote URL. This is highly
#'   recommend as it prevents you from accidentally running code that's not
#'   what you expect. See \code{\link{source_url}} for more information on
#'   using a SHA-1 hash.
#' @param quiet if \code{FALSE}, the default, prints informative messages.
#' @export
#' @examples
#' \dontrun{
#' # You can run gists given their id
#' source_gist(6872663)
#' source_gist("6872663")
#'
#' # Or their html url
#' source_gist("https://gist.github.com/hadley/6872663")
#' source_gist("gist.github.com/hadley/6872663")
#'
#' # It's highly recommend that you run source_gist with the optional
#' # sha1 argument - this will throw an error if the file has changed since
#' # you first ran it
#' source_gist(6872663, sha1 = "54f1db27e60")
#' # Wrong hash will result in error
#' source_gist(6872663, sha1 = "54f1db27e61")
#'
#' #' # You can speficy a particular R file in the gist
#' source_gist(6872663, filename = "hi.r")
#' source_gist(6872663, filename = "hi.r", sha1 = "54f1db27e60")
#' }
source_gist <- function(id, ..., filename = NULL, sha1 = NULL, quiet = FALSE) {
  stopifnot(length(id) == 1)

  url_match <- "((^https://)|^)gist.github.com/([^/]+/)?([0-9a-f]+)$"
  if (grepl(url_match, id)) {
    # https://gist.github.com/kohske/1654919, https://gist.github.com/1654919,
    # or gist.github.com/1654919
    id <- regmatches(id, regexec(url_match, id))[[1]][5]
    url <- find_gist(id, filename)
  } else if (is.numeric(id) || grepl("^[0-9a-f]+$", id)) {
    # 1654919 or "1654919"
    url <- find_gist(id, filename)
  } else {
    stop("Unknown id: ", id)
  }

  if (!quiet) message("Sourcing ", url)
  source_url(url, ..., sha1 = sha1)
}

find_gist <- function(id, filename) {
  files <- github_GET(sprintf("gists/%s", id))$files
  r_files <- files[grepl("\\.[rR]$", names(files))]

  if (length(r_files) == 0) {
    stop("No R files found in gist", call. = FALSE)
  }

  if (!is.null(filename)) {
    if (!is.character(filename) || length(filename) > 1 || !grepl("\\.[rR]$", filename)) {
      stop("'filename' must be NULL, or a single filename ending in .R/.r")
    }

    which <- match(tolower(filename), tolower(names(r_files)))
    if (is.na(which)) {
      stop("You have speficied a file that is not in this gist.")
    }

  } else {
    if (length(r_files) > 1) {
      warning("Multiple R files in gist, using first.")
      which <- 1
    }
  }

  r_files[[which]]$raw_url
}
