# --------------------------------------------------------- #
# Format raw data as a list of tables                       #
# TEMPLATE                                                       #
# Revised 01 Jun 2017                                       #
# --------------------------------------------------------- #

# Contributors: Riley Andrade, Max Castorani, Nina Lany, Sydne Record, Nicole Voelker

# Clear environment
rm(list = ls())

# Set your working environment to the GitHub repository, e.g.: 
#setwd("~/Documents/ltermetacommunities")

#Check to make sure working directory is correct
if(basename(getwd())!="ltermetacommunities"){cat("Plz change your working directory. It should be 'ltermetacommunities'")}

# Check for and install required packages
for (package in c('dplyr', 'tidyr', 'vegetarian', 'vegan', 'metacom', 'ggplot2')) {
  if (!require(package, character.only=T, quietly=T)) {
    install.packages(package)
    library(package, character.only=T)
  }
}

# ---------------------------------------------------------------------------------------------------

# Assign data set of interest
# NOTE: Google Drive file ID is different for each dataset

# CAP LTER (Central Arizona-Phoenix)
data.set <- "CAP-birds-CORE"
data.key <- "0BzcCZxciOlWgeHJ5SWx1YmplMkE" # Google Drive file ID 

# NWT LTER (Niwot Ridge)
data.set <- "NWT-plants-Hallett-and-Sokol"
data.key <- "0B2P104M94skvQVprSnBsYjRzVms" # Google Drive file ID 


# SBC LTER (Santa Barbara Coastal): Macroalgae
data.set <- "SBC-algae-Castorani_Lamy"
data.key <- "0BxUZSA1Gn1HZRUxaNmV1Y21abmc" # Google Drive file ID 

# SBC LTER (Santa Barbara Coastal): Sessile invertebrates
data.set <- "SBC-sessile_invert-Castorani_Lamy"
data.key <- "0BxUZSA1Gn1HZUFdnUGxKNW9ocFE" # Google Drive file ID 

# SBC LTER (Santa Barbara Coastal): Mobile invertebrates
data.set <- "SBC-mobile_invert-Castorani_Lamy"
data.key <- "0BxUZSA1Gn1HZRmZWOGM5c3F5aEE" # Google Drive file ID 

# SBC LTER (Santa Barbara Coastal): Fishes
data.set <- "SBC-fish-Castorani_Lamy"
data.key <- "0BxUZSA1Gn1HZZU1vYWJWY0lMc0k" # Google Drive file ID 

# ---------------------------------------------------------------------------------------------------
# IMPORT DATA
dat.long <-  read.csv(sprintf("https://docs.google.com/uc?id=%s&export=download", data.key)) %>%
  dplyr::select(-X) # Remove column that contains rownames

# MAKE DATA LIST
dat <- list()

# COMMUNITY DATA 
comm.long <- dat.long[dat.long$OBSERVATION_TYPE == "TAXON_COUNT", ] 
comm.long <- comm.long %>%
  droplevels()

# Subset data if necessary
#comm.long <- subset(comm.long, comm.long$TAXON_GROUP != "INSERT NAME OF REMOVAL GROUP HERE")
#comm.long <- droplevels(comm.long)
str(comm.long)  # Inspect the structure of the community data

#Add number of unique taxa and number of years to data list:
dat$n.spp <- length(levels(comm.long$VARIABLE_NAME))
dat$n.years <- length(unique(comm.long$DATE))
# Ensure that community data VALUE and DATE are coded as numeric
comm.long <- comm.long %>%   # Recode if necessary
  mutate_at(vars(c(DATE, VALUE)), as.numeric)

# Ensure that community character columns coded as factors are re-coded as characters
comm.long <- comm.long %>%   # Recode if necessary
  mutate_if(is.factor, as.character)
  
# Ensure that SITE_ID is a character: recode numeric as character 
comm.long <- comm.long %>%   # Recode if necessary
  mutate_at(vars(SITE_ID), as.character)

# Double-check that all columns are coded properly
ifelse(FALSE %in% 
   c(
     class(comm.long$OBSERVATION_TYPE) == "character",
     class(comm.long$SITE_ID) == "character",
     class(comm.long$DATE) == "numeric",
     class(comm.long$VARIABLE_NAME) == "character",
     class(comm.long$VARIABLE_UNITS) == "character",
     class(comm.long$VALUE) == "numeric"
     #class(comm.long$TAXON_GROUP) == "character")
   ),
  "ERROR: Community columns incorrectly coded.", 
  "OK: Community columns correctly coded.")

# ---------------------------------------------------------------------------------------------------
# Check balanced sampling of species across space and time by inspecting table, and add to data list
xtabs(~ SITE_ID + DATE, data = comm.long)
hist(na.omit(comm.long$DATE))

ifelse(length(unique(xtabs(~ SITE_ID + DATE, data = comm.long))) == 1,
       "OK: Equal number of taxa recorded across space and time.", 
       "ERROR: Unequal numbers of observations across space and time, or taxa list not fully propagated across space and time. Inspect contingency table.")

# ---------------------------------------------------------------------------------------------------
# Add to dat list the unique taxa
dat$comm.long <- comm.long

# Convert community data to wide form
comm.wide <- comm.long %>%
  select(-VARIABLE_UNITS) %>%
  spread(VARIABLE_NAME,  VALUE)

dat$comm.wide <- comm.wide
summary(dat)

# ---------------------------------------------------------------------------------------------------
# SPATIAL DATA
# Check for and install required packages

for (package in c('dplyr', 'tidyr', 'XML', 'sp', 'geosphere', 'rgdal','maps','reshape2','ggplot2')) {
  if (!require(package, character.only=T, quietly=T)) {
    install.packages(package)
    library(package, character.only=T)
  }
}

#pull out coordinate data and make sure that it is numeric
cord <- filter(dat.long, OBSERVATION_TYPE=="SPATIAL_COORDINATE");head(cord)
cord$SITE_ID <- toupper(cord$SITE_ID)  # Ensure sites are in all caps
cord <- droplevels(cord)
str(cord)

cord.wide <- cord %>%
  select(-VARIABLE_UNITS) %>%
  spread(VARIABLE_NAME,  VALUE)

head(cord.wide)

sites <- c(unique(cord.wide$SITE_ID));sites

# keep the records that are _not_ duplicated
cord.wide <- subset(cord.wide, !duplicated(SITE_ID));dim(cord.wide)  # here we selcet rows (1st dimension) that are different from the object dups2 (duplicated records)
cord.wide
cord.wide$latitude <- as.numeric(as.character(cord.wide$LAT)) 
cord.wide$longitude <- as.numeric(as.character(cord.wide$LONG)) #cord.wide$longitude <- as.numeric(as.character(cord.wide$longitude))
cord.wide <- cord.wide[c("longitude", "latitude")] #pull last two columns and reorder

#add number of sites and long/lat coords to data list:
dat$n.sites <- length(sites)
dat$longlat <- cord.wide

#make data spatially explicit
coordinates(cord.wide) = c("longitude", "latitude") #coordinates(cord.wide) <- c("longitude", "latitude") 
crs.geo <- CRS("+proj=longlat +ellps=WGS84 +datum=WGS84")  # SBC
crs.geo <- CRS("+proj=utm +zone=13 +datum=WGS84") #NWT, PHX=zone12
proj4string(cord.wide) <- crs.geo  # define projection system of our data to WGS84 (CHECK TO SEE IF THIS WORKS IF SPATIAL COORDINATE IS NOT IN DEC.DEGREES)
summary(cord.wide) 

#if DATA IS IN UTM OR OTHER KNOWN COORDINATE SYSTEM YOU CAN TRANSFORM IT, EG... UTM data for PHX and NWT 
cord.wide <- spTransform(cord.wide, CRS("+proj=longlat")) 
summary(cord.wide) #check transformation

#create a distance matrix between sites, best fit distance function TBD
distance.mat <- (distm(cord.wide, fun = distVincentyEllipsoid)/1000);distance.mat #km distance
rownames(distance.mat) <- sites
colnames(distance.mat) <- sites

#add distance matrix to data list
dat$distance.mat <- distance.mat
summary(dat)
# ---------------------------------------------------------------------------------------------------
# ENVIRONMENTAL COVARIATES
env.long <- subset(dat.long, OBSERVATION_TYPE == "ENV_VAR")
env.long <- droplevels(env.long)
str(env.long)

# Convert from long to wide
env.wide <- env.long %>%
  select(-VARIABLE_UNITS) %>%
  tidyr::spread(VARIABLE_NAME,  VALUE)

# Add environmental covaiates to data list

dat$n.covariates <- length(levels(env.long$VARIABLE_NAME))
dat$cov.names <- levels(env.long$VARIABLE_NAME)
dat$env <- env.wide
dat$env.long <- env.long

#CHECK: 
# Are all year-by-site combinations in community data matched by environmental data?
ifelse(nrow(dat$comm.wide) == nrow(dat$env), "Yes", "No")

# Are community data balanced over space and time?
ifelse(nrow(dat$comm.wide) == dat$n.years * dat$n.sites, "Yes", "No")

# Inspect summary of 'dat' list 
summary(dat)

#write .Rdata object into the "Intermediate_data" directory 
filename <- paste(data.set,".Rdata", sep="")
save(dat, file = paste("Intermediate_data/",filename,sep=""))

#clean up the workspace
rm("comm.long","comm.wide","cord","cord.wide","crs.geo","dat.long", "data.key", "data.set","distance.mat","env.long", "env.wide","package","sites")
ls()

# Now, explore the data and perform further QA/QC by sourcing this script within the scripts "2_explore_spatial_dat.R", "3_explore_comm_dat.R", and "4_explore_environmental_dat.R"

# ---------------------------------------------------------------------------------------------------
## WRITE OUT DATA FOR ARCHIVING ##
#save flat files into 'final_data' folder on Google Drive. 

##### OLD WAY #####
#write .Rdata object into the "Intermediate_data" directory 
#filename <- paste(data.set,".Rdata", sep="")
#save(dat, file = paste("Intermediate_data/",filename,sep=""))


