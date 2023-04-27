#' Retuirve the base URI for the homr API
#' 
#' @export
#' @param ... path segments passed to \code{file.path}
#' @param root char, the root address
#' @return char URI
api_uri = function(..., root = "http://www.ncdc.noaa.gov/homr/services/station"){
  file.path(root, ...)
}

#' Query homr using the search endpoint
#' 
#' @export
#' @param ... elements of the query to be cast and \code{character} type
#' @param headersOnly logical, if TRUE retrieve just identifying info as well
#'   as startDate and endDate - this makes the search faster.  Ignored if 
#'   \code{params} is provided.
#' @param definitions logical, if TRUE add definitions as an attribute
#'   of the returned value. Ignored if \code{params} is provided.
#' @param params char or NULL, if provided then a complete set of query
#'  parameters such as "state=DE&headersOnly=true&defintions=false". If provided
#'  then \code{...}, \code{headersOnly} and \code{definitions} are ignored.
#'  @param verbose logical, if TRUE output helpful messages
#' @param base_uri char, the base uri
#' @return tibble 
query_search = function(..., 
                        headersOnly = TRUE,
                        definitions = FALSE, 
                        params = NULL, 
                        verbose = FALSE,
                        base_uri = api_uri("search")){
  
  if (is.null(params)){
    # /homr/services/station/search?headersOnly=true&state=DE
    pp = list(...) 
    pp[['headersOnly']] = headersOnly[1]
    pp[['definitions']] = definitions[1]
    params = sapply(names(pp),
               function(nm){
                 if(inherits(pp[[nm]], 'Date')){
                   x = format(pp[[nm]], "%Y-%m-%d")
                 } else if (is.logical(pp[[nm]])){
                   x = as.character(pp[[nm]]) |> tolower()
                 } else if (is.numeric(pp[[nm]])){
                   x = as.character(pp[[nm]])
                 } else {
                   x = pp[[nm]]
                 }
                 paste0(nm, "=", x)
               }) |>
      paste0(collapse = "&")
  } else {
    stopifnot(is.character(params))
  }
  
  
  uri = httr::modify_url(base_uri, query = params)
  
  if (verbose) cat("query uri is", uri, "\n")
  
  xlist = httr::GET(uri, httr::accept_json()) |>
    httr::stop_for_status() |>
    httr::content( "text", encoding = 'UTF-8') |>
    jsonlite::fromJSON(, flatten = TRUE)
  

  x <- xlist$stationCollection$stations |>
    dplyr::as_tibble()
  cnames = sub("header.", "", colnames(x), fixed = TRUE)
  cnames = sub("por.", "", cnames, fixed = TRUE)
  colnames(x) <- cnames
  x = sf::st_as_sf(x, coords = c("longitude_dec", "latitude_dec"), crs = 4326)
  
  if (!is.null(xlist$stationCollection$definitions)) {
    attr(x, "homr_definitions") <- xlist$stationCollection$definitions |>
      dplyr::as_tibble()
  }
  
  x
}

