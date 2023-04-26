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
#' @param include_definitions logical, if TRUE add definitions as an attribute
#'   of the returned value
#' @param base_uri char, the base uri
#' @return tibble 
query_search = function(..., 
                        include_definitions = FALSE, 
                        base_uri = api_uri("search")){
  
  # /homr/services/station/search?headersOnly=true&state=DE
  pp = list(...) |> unlist()
  p = sapply(names(pp),
             function(nm){
               if(inherits(pp[[nm]], 'Date')){
                 x= format(pp[[nm]], "%Y-%m-%d")
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
  
  #cat(p, "\n")
  
  uri = httr::modify_url(base_uri, query=p)
  resp = httr::GET(uri, httr::accept_json()) |>
    httr::stop_for_status(resp)
  xlist = jsonlite::fromJSON(httr::content(resp, "text", encoding = 'UTF-8'), 
                         flatten = TRUE)
  
  
  
  x <- xlist[["stationCollection"]][['stations']] |>
    dplyr::as_tibble()
  cnames = sub("header.", "", colnames(x), fixed = TRUE)
  cnames = sub("por.", "", cnames, fixed = TRUE)
  colnames(x) <- cnames
  x = sf::st_as_sf(x, coords = c("longitude_dec", "latitude_dec"), crs = 4326)
  if (include_definitions) {
    attr(x, "homr_definitions") <- xlist[["stationCollection"]][['definitions']] |>
      dplyr::as_tibble()
  }
  x
}

