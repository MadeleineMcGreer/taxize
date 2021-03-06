#' Get the UID codes from NCBI for taxonomic names.
#'
#' Retrieve the Unique Identifier (UID) of a taxon from NCBI taxonomy browser.
#'
#' @import plyr RCurl
#' @param sciname character; scientific name.
#' @param ask logical; should get_tsn be run in interactive mode?
#' If TRUE and more than one TSN is found for the species, the user is asked for
#' input. If FALSE NA is returned for multiple matches.
#' @param verbose logical; If TRUE the actual taxon queried is printed on the console.
#' @param rows numeric; Any number from 1 to inifity. If the default NA, all rows are considered.
#' Note that this function still only gives back a uid class object with one to many identifiers.
#' See \code{\link[taxize]{get_uid_}} to get back all, or a subset, of the raw data that you are
#' presented during the ask process.
#' @param x Input to \code{\link{as.uid}}
#' @param ... Ignored
#' @param check logical; Check if ID matches any existing on the DB, only used in
#' \code{\link{as.uid}}
#'
#' @return A vector of unique identifiers (UID). If a taxon is not found NA.
#' If more than one UID is found the function asks for user input (if ask = TRUE),
#' otherwise returns NA. Comes with an attribute \emph{match} to investigate the
#' reason for NA (either 'not found', 'found' or if ask = FALSE 'multi match').
#' If \code{ask=FALSE} and \code{rows} does not equal NA, then a data.frame is
#' given back, but not of the uid class, which you can't pass on to other functions
#' as you normally can.
#'
#' @seealso \code{\link[taxize]{get_tsn}}, \code{\link[taxize]{classification}}
#'
#' @export
#' @author Eduard Szoecs, \email{eduardszoecs@@gmail.com}
#'
#' @examples \dontrun{
#' get_uid(c("Chironomus riparius", "Chaetopteryx"))
#' get_uid(c("Chironomus riparius", "aaa vva"))
#'
#' # When not found
#' get_uid("howdy")
#' get_uid(c("Chironomus riparius", "howdy"))
#'
#' # specify rows to limit choices available
#' get_uid('Dugesia') # user prompt needed
#' get_uid('Dugesia', rows=1) # 2 choices, so returns only 1 row, so no choices
#' get_uid('Dugesia', ask = FALSE) # returns NA for multiple matches
#' get_uid('Dugesia', ask = FALSE) # or specify rows to get data back
#'
#' # Go to a website with more info on the taxon
#' res <- get_uid("Chironomus riparius")
#' browseURL(attr(res, "uri"))
#'
#' # Convert a uid without class information to a uid class
#' as.uid(get_uid("Chironomus riparius")) # already a uid, returns the same
#' as.uid(get_uid(c("Chironomus riparius","Pinus contorta"))) # same
#' as.uid(315567) # numeric
#' as.uid(c(315567,3339,9696)) # numeric vector, length > 1
#' as.uid("315567") # character
#' as.uid(c("315567","3339","9696")) # character vector, length > 1
#' as.uid(list("315567","3339","9696")) # list, either numeric or character
#' ## dont check, much faster
#' as.uid("315567", check=FALSE)
#' as.uid(315567, check=FALSE)
#' as.uid(c("315567","3339","9696"), check=FALSE)
#' as.uid(list("315567","3339","9696"), check=FALSE)
#'
#' (out <- as.uid(c(315567,3339,9696)))
#' data.frame(out)
#' as.uid( data.frame(out) )
#'
#' # Get all data back
#' get_uid_("Puma concolor")
#' get_uid_("Dugesia")
#' get_uid_("Dugesia", rows=2)
#' get_uid_("Dugesia", rows=1:2)
#' get_uid_(c("asdfadfasd","Pinus contorta"))
#' }

get_uid <- function(sciname, ask = TRUE, verbose = TRUE, rows = NA){
  repeat_until_it_works <- function(func, catch, max_tries = 3, wait_time = 10, verbose = TRUE, ...) {
    error_handler <- function(e) {
      if (e$message %in% catch) {
        if (verbose) warning(paste("Caught error:", e$message))
        return(NA)
      } else {
        stop(e$message)
      }
    }
    for (count in 1:max_tries) {
      output <- tryCatch({func(...)}, error = error_handler)
      if (!is.na(output)) return(output)
      Sys.sleep(wait_time * count)
    }
    return(output)
  }

  fun <- function(sciname, ask, verbose, rows) {
    mssg(verbose, "\nRetrieving data for taxon '", sciname, "'\n")
    sciname <- gsub(" ", "+", sciname)
    searchurl <- paste("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=taxonomy&term=",
                       sciname, sep = "")
    # NCBI limits requests to three per second
    #     xml_result <- xmlParse(getURL(url = searchurl))
    errors_to_catch <- c("Could not resolve host: eutils.ncbi.nlm.nih.gov")
    xml_result <- xmlParse(repeat_until_it_works(getURL,
                                                 catch = errors_to_catch,
                                                 url = searchurl))
    Sys.sleep(0.33)
    uid <- xpathSApply(xml_result, "//IdList/Id", xmlValue)
    if (length(uid) == 0) { # if taxon name is not found
      uid <- NA
    } else {
      uid <- sub_vector(uid, rows)
    }
    att <- 'found'
    # not found on ncbi
    if (length(uid) == 0){
      mssg(verbose, "Not found. Consider checking the spelling or alternate classification")
      uid <- NA
      att <- 'not found'
    }
    # more than one found on ncbi -> user input
    if(length(uid) > 1){
      if(ask){
        baseurl <- "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=taxonomy"
        ID <- paste("ID=", paste(uid, collapse= ","), sep = "")
        searchurl <- paste(baseurl, ID, sep = "&")
        #         tt <- getURL(searchurl)
        errors_to_catch <- c("Could not resolve host: eutils.ncbi.nlm.nih.gov")
        tt <- repeat_until_it_works(getURL,
                                    catch = errors_to_catch,
                                    url = searchurl)
        ttp <- xmlTreeParse(tt, useInternalNodes = TRUE)
        df <- ldply(xmlToList(ttp), data.frame)
        df <- df[df$Item..attrs != 'String', c(2,5,7)]
        names(df) <- c("UID", "Rank", "Division")
        rownames(df) <- 1:nrow(df)
        # df <- get_rows(df, rows)

        # prompt
        message("\n\n")
        message("\nMore than one UID found for taxon '", sciname, "'!\n
            Enter rownumber of taxon (other inputs will return 'NA'):\n")
        print(df)
        take <- scan(n = 1, quiet = TRUE, what = 'raw')

        if(length(take) == 0){
          take <- 'notake'
          att <- 'nothing chosen'
        }
        if(take %in% seq_len(nrow(df))){
          take <- as.numeric(take)
          message("Input accepted, took UID '", as.character(df$UID[take]), "'.\n")
          uid <- as.character(df$UID[take])
          att <- 'found'
        } else {
          uid <- NA
          att <- 'not found'
          mssg(verbose, "\nReturned 'NA'!\n\n")
        }
      } else {
        uid <- NA
        att <- 'NA due to ask=FALSE'
      }
    }
    return(data.frame(uid, att, stringsAsFactors= FALSE))
  }
  sciname <- as.character(sciname)
  outd <- ldply(sciname, fun, ask, verbose, rows)
  out <- structure(outd$uid, class="uid", match=outd$att)
  add_uri(out, 'http://www.ncbi.nlm.nih.gov/taxonomy/%s')
}

#' @export
#' @rdname get_uid
as.uid <- function(x, check=TRUE) UseMethod("as.uid")

#' @export
#' @rdname get_uid
as.uid.uid <- function(x, check=TRUE) x

#' @export
#' @rdname get_uid
as.uid.character <- function(x, check=TRUE) if(length(x) == 1) make_uid(x, check) else collapse(x, make_uid, "uid", check=check)

#' @export
#' @rdname get_uid
as.uid.list <- function(x, check=TRUE) if(length(x) == 1) make_uid(x, check) else collapse(x, make_uid, "uid", check=check)

#' @export
#' @rdname get_uid
as.uid.numeric <- function(x, check=TRUE) as.uid(as.character(x), check)

#' @export
#' @rdname get_uid
as.uid.data.frame <- function(x, check=TRUE) structure(x$ids, class="uid", match=x$match, uri=x$uri)

#' @export
#' @rdname get_uid
as.data.frame.uid <- function(x, ...){
  data.frame(ids = as.character(unclass(x)),
             class = "uid",
             match = attr(x, "match"),
             uri = attr(x, "uri"),
             stringsAsFactors = FALSE)
}

make_uid <- function(x, check=TRUE) make_generic(x, 'http://www.ncbi.nlm.nih.gov/taxonomy/%s', "uid", check)

check_uid <- function(x){
  url <- "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=taxonomy&id="
  res <- GET(paste0(url, x))
  tt <- content(res)
  tryid <- xpathSApply(tt, "//Id", xmlValue)
  identical(x, tryid)
}


#' @export
#' @rdname get_uid
get_uid_ <- function(sciname, verbose = TRUE, rows = NA){
  setNames(lapply(sciname, get_uid_help, verbose = verbose, rows = rows), sciname)
}

get_uid_help <- function(sciname, verbose, rows){
  mssg(verbose, "\nRetrieving data for taxon '", sciname, "'\n")
  searchurl <- paste("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=taxonomy&term=",
                     gsub(" ", "+", sciname), sep = "")
  xml_result <- xmlParse(getURL(searchurl))
  Sys.sleep(0.33)
  uid <- xpathSApply(xml_result, "//IdList/Id", xmlValue)
  if(length(uid) == 0){ NULL } else {
    baseurl <- "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=taxonomy"
    ID <- paste("ID=", paste(uid, collapse= ","), sep = "")
    searchurl <- paste(baseurl, ID, sep = "&")
    tt <- getURL(searchurl)
    ttp <- xmlTreeParse(tt, useInternalNodes = TRUE)
    df <- ldply(xmlToList(ttp), data.frame)
    df <- setNames(df[df$Item..attrs != 'String', c(2,5,7)], c("UID", "Rank", "Division"))
    sub_rows(df, rows)
  }
}
