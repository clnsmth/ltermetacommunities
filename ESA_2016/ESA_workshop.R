# ---------------------------- #
# ESA Workshop - 8 August 2016 #
# ---------------------------- #

# Set working environment
rm(list = ls())
setwd("ESA_2016")

# Check for and install required packages
for (package in c('dplyr', 'tidyr', 'vegetarian', 'vegan', 'metacom')) {
  if (!require(package, character.only=T, quietly=T)) {
    install.packages(package)
    library(package, character.only=T)
  }
}

# Read in NWT plant community data and site coordinates 
nwt.xy <- read.csv("NWT_coordinates.csv")
nwt.comm.long <- read.csv("NWT_plantcomp.csv")[,c(2,4,5,6)]
nwt.comm.wide <- tidyr::spread(nwt.comm.long, 
                               USDA_code, abund,
                               fill = 0)

dim(nwt.comm.wide)


# Function to pass long form data frames to metacom package
fn.ems.long <- function(
  site.id.vect,
  spp.vect,
  abund.vect,
  ...){
  df.wide <- tidyr::spread(
    data.frame(
      site.id.vect,
      spp.vect,
      abund.vect
  ),
  spp.vect,
  abund.vect,
  fill = 0)[,-1]
  
  # df.wide <- df.wide[,-which(colSums(df.wide) == 0)]
  # df.wide <- df.wide[-which(rowSums(df.wide) == 0),]

  IdentifyStructure(metacom::Metacommunity(
    comm = (df.wide > 0) * 1,...))
}

# Create data frame of EMS for each time step
ems.by.year <- nwt.comm.long %>% group_by(year) %>% summarise(
  ems = fn.ems.long(plot, USDA_code, abund, method = 'r1', sims = 10)
)

# Test on individual year
nwt.1989 <- filter(nwt.comm.wide, year == 1989)
head(nwt.1989)
nwt.1989 <- nwt.1989[,-which(colSums(nwt.1989) == 0)]
nwt.1989[,which(colSums(nwt.1989) == 0)]
ems.1989 <- Metacommunity(
  decostand(nwt.1989[,-c(1:2)], method = "pa"),
  method = "r1", sims = 100)
IdentifyStructure(ems.1989)


# Implementing by looping, rather than dplyr and tidyr.
# Seems to work fine, interesting to note that the 
# site seems to continually display checkerboard patterns
# for the past 20 years or so.



fn.ems.loop <- function(comm.wide){
  
  for(year.i in unique(comm.wide$year)){
    comm.year <- filter(comm.wide, year == year.i)[,-c(1:2)] # remove plot & year cols
    comm.year.pa <- decostand(comm.year, method = "pa")
    comm.year.pa <- comm.year.pa[,which(colSums(comm.year.pa) > 0)] # remove empty cols and rows
    comm.year.pa <- comm.year.pa[which(rowSums(comm.year.pa) > 0),]
    ems.year <- Metacommunity(
      comm.year.pa,
      method = "r1", sims = 100)
    print(ems.year) # print raw values from EMS analysis
    print(IdentifyStructure(ems.year))  # prints the structure of the MC
  }

}

# run function
fn.ems.loop(nwt.comm.wide)
