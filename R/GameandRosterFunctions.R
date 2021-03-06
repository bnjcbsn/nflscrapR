################################################################## 
###               Game and Roster Functions                    ###
# Author: Maksim Horowitz                                        #
# Code Style Guide: Google R Format                              #
##################################################################

# Games in a Season
#' Game Information for All Games in a Season
#' @description This function intakes a year associated with a given season
#' and outputs all the game matchups for all 17 weeks of the regular season
#' @param Season (numeric) A 4-digit year associated with a given NFL season
#' @param Week (numeric): A number corresponding to the number of weeks of data
#' you want to be scraped and included in the output.
#' @return A dataframe with the gameID, the game date, 
#' the home team abbreviation, and away team abbreviation 
#' @details Reference the stored dataframe nflteams to match team abbreviations
#' with the full team names
#' @examples
#' # All games in 2015 Season
#' season_games(2015) # Will output a dataframe
#' @export
season_games <- function(Season, Weeks = 17) {
  
  game_ids <- extracting_gameids(Season)
  
  game_weeks <- get_gameweeks(Season)
  
  game_ids <- game_ids[game_weeks<=Weeks]
  
  game_urls <- sapply(game_ids, proper_jsonurl_formatting)
  
  # Game Dates
  year <- substr(game_ids, start = 1, stop = 4)
  month <- substr(game_ids, start = 5, stop = 6)
  day <- substr(game_ids, start = 7, stop = 8)
  date <- as.Date( paste(month, day, year, sep = "/"), format = "%m/%d/%Y")
  
  # Home and Away Teams
  
  teams.unformatted <- lapply(game_urls, 
                              FUN = function(x) {
                                cbind(t(sapply(RJSONIO::fromJSON(RCurl::getURL(x))[[1]]$home[2]$abbr,
                                               c)),
                                      t(sapply(RJSONIO::fromJSON(RCurl::getURL(x))[[1]]$away[2]$abbr,
                                               c)))
                              })
  
  teams <- do.call(rbind, teams.unformatted)
  
  # Home and Away Team Scores 
  
  scores.unformatted <- lapply(game_urls, 
                               FUN = function(x) {
                                 cbind(t(sapply(max(RJSONIO::fromJSON(RCurl::getURL(x))[[1]]$home$score),
                                                c)),
                                       
                                       t(sapply(max(RJSONIO::fromJSON(RCurl::getURL(x))[[1]]$away$score),
                                                c)))
                               })
  
  score <- do.call(rbind, scores.unformatted)

  # Output Dataframe
  
  data.frame(GameID = game_ids, date = date, home = teams[,1], away = teams[,2],
             homescore = score[,1], awayscore = score[,2])
}


################################################################## 
#' Season Rosters for Teams
#' @description This function intakes a year and a team abbreviation and outputs
#' a dataframe with each player who has played for the specified team and 
#' recorded a measurable statistic
#' @param Season: A 4-digit year associated with a given NFL season
#' @param TeamInt: A string containing the abbreviations for an NFL Team
#' @param Week (numeric): A number corresponding to the number of weeks of data
#' you want to be scraped and included in the output.
#' @details To find team associated abbrevations use the nflteams dataframe 
#' stored in this package!
#' @return A dataframe with columns associated with season/year, team, playerID,
#' players who played and recorded some measurable statistic, and the 
#' last column specifyng the number of games they played in.
#' @examples
#' # Roster for Baltimore Ravens in 2013
#' season_rosters(2013, TeamInt = "BAL") 
#' @export
season_rosters <- function(Season, Weeks = 17, TeamInt) {
  
  # Use the season_playergame to gather all names of players on a given team
  team.roster.s1 <- subset(season_player_game(Season, Weeks = Weeks), 
                           Team == TeamInt)
  
  # Use dplyr to subset the data and gather games played
  team.roster <- dplyr::group_by(team.roster.s1, Season, Team, playerID, name)
  team.roster <- dplyr::summarize(team.roster, length(playerID))
  
  colnames(team.roster)[ncol(team.roster)] <- "gamesplayed"
  
  # Output Dataframe
  team.roster
}

#' Extract week numbers of the season for each game in a given NFL season
#' @description This function is a helper for filtering 
#' @return A vector of NFL week numbers, corresponding to game_ids, from the specified season
#' @examples
#' game_ids <- extracting_gameids(Season)
#' game_weeks <- get_gameweeks()
#' @export
get_gameweeks <- function(Season){
  game_ids <- extracting_gameids(Season)
  games <- dplyr::data_frame(game_ids)
  # parse game date from game_id
  games$game.date <- lubridate::ymd(substr(games$game_ids, 1, 8))
  # calc calendar week, adjust for a Thursday beg week, and pre-date 12
  # weeks to keep seasons together, -3 days, -84 days
  # -0 days = Monday start week, -1 days equals Tuesday, etc
  games$calweek <- lubridate::isoweek(games$game.date-87)
  # no value, used in testing
  games$wday <- lubridate::wday(games$game.date, label = TRUE)
  # use calendar week values to determine seasonweek
  games$season.week <- games$calweek - (min(games$calweek)-1)
  # repeat method to populate vector
  gameweeks <- games$calweek - (min(games$calweek)-1)
  gameweeks
}