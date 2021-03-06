# join helpers
initial_prep = function(from_tbl, to_tbl, key, join_type, show_msg) {
  from_ind = which(colnames(from_tbl) == key)
  to_ind = which(colnames(to_tbl) == key)
  initial = sapply(to_tbl[,to_ind], FUN = function(x) which(from_tbl[,from_ind] == x))
  initial = lapply(initial, FUN = function(x) {
    if(length(x) == 0) {
      return(-1)
    } else {
      return(x)
    }
  })
  # when the msg pops up before or after the linking lines
  when = lapply(initial, getwhen) %>% Reduce(rbind, .) %>% as.vector()
  # msg to pop up
  msg = lapply(initial, function(x) getmsg(x, join_type)) %>% Reduce(rbind, .) %>%
    as.vector()
  # filter some msg so not all of them will show up
  uq <- name <- NULL # quiet R CMD check NOTE

  msg = data.frame(name = names(initial), msg = as.character(msg))
  msg = msg %>% group_by(msg) %>% mutate(uq = row_number()) %>%
    ungroup() %>% mutate(msg = as.character(msg)) %>%
    mutate(msg = ifelse(uq == 1, msg, NA)) %>% select(-uq)
  # input the names in
  msg = msg %>% rowwise() %>% transmute(msg = gsub("_val_", name, msg)) %>%
    pull(msg)

  # prepare for unnest
  initial = tibble(row = seq(length(initial)), dest = initial)
  if(isTRUE(show_msg)) {
    initial = initial %>% mutate(msg = msg, when = when)
  }
  # unnest and split
  initial = initial %>% unnest() %>% split(.$row)

  return(initial)
}
find_key_col = function(obj, key, minus1 = FALSE){
  ans = which(colnames(obj) == key)
  if(minus1 == TRUE){
    return(ans - 1)
  }else{
    return(ans)
  }
}
xy_loc = function(from_tbl, to_tbl, result_tbl, key, minus1 = FALSE) {
  # Quiet R CMD check note
  start <- stop <- NULL

  result_tbl = result_tbl %>% mutate(stop = row_number())
  from_cn = colnames(from_tbl)
  from_tbl = from_tbl %>% mutate(start = row_number())
  out = left_join(result_tbl, from_tbl, by = from_cn) %>%
    select(start, stop) %>% na.omit() %>% arrange(stop)
  return(out)
}
xy_loc2 = function(from_tbl, to_tbl, result_tbl, key, minus1 = FALSE) {
  result_tbl = result_tbl %>% group_by(!!!syms(colnames(to_tbl))) %>%
    mutate(addrow = row_number()) %>% ungroup()

  from_cn = colnames(from_tbl)
  from_tbl = from_tbl %>% mutate(start = row_number())
  to_cn = colnames(to_tbl)
  to_tbl = to_tbl %>% mutate(split = row_number())

  result_tbl = left_join(result_tbl, from_tbl, by = from_cn) %>%
    left_join(., to_tbl, by = to_cn) %>%
    mutate(stop = row_number())
  # Quiet R CMD check note
  start <- stop <- addrow <- NULL
  if(minus1) {
    result_tbl = result_tbl %>%
      mutate(start = start - 1, stop = stop - 1)
  }

  out = result_tbl %>%
    select(split, start, stop, addrow) %>%
    na.omit() %>% # %>% maybe need to arrange by stop here?
    split(x = ., f = .$split)

  out = lapply(out, function(xx) xx %>% select(-split))

  return(out)
}
getmsg = function(x, join_type) {
  na_msg = switch(join_type, inner = "No match for _val_. \nDelete", "No match for _val_")
  if(length(x) > 1) {
    return(sprintf("%s matches found for \n_val_", length(x)))
  }else if(x == -1) {
    return(na_msg)
  }else if(length(x) == 1) {
    return("Matching _val_")
  }
}
getwhen = function(x) {
  if(length(x) > 1) {
    return("after")
  }else if(x == -1) {
    return("after")
  }else if(length(x) == 1) {
    return("before")
  }
}
