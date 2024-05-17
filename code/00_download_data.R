########################
### 0. Download Data ###
########################

# clear environment
rm(list = ls())

# calculate start time of code (determine how long it takes to complete all code)
start <- Sys.time()

#####################################
#####################################

# load packages
if (!require("pacman")) install.packages("pacman")
pacman::p_load(docxtractr,
               dplyr,
               elsa,
               fasterize,
               fs,
               ggplot2,
               janitor,
               ncf,
               paletteer,
               pdftools,
               plyr,
               purrr,
               raster,
               RColorBrewer,
               reshape2,
               rgdal,
               rgeoda,
               rgeos,
               rmapshaper,
               rnaturalearth, # use devtools::install_github("ropenscilabs/rnaturalearth") if packages does not install properly
               sf,
               sp,
               stringr,
               terra, # is replacing the raster package
               tidyr)

#####################################
#####################################

# Commentary on R and code formulation:
## ***Note: If not familiar with dplyr notation
## dplyr is within the tidyverse and can use %>%
## to "pipe" a process, allowing for fluidity
## Can learn more here: https://style.tidyverse.org/pipes.html

## Another common coding notation used is "::"
## For instance, you may encounter it as dplyr::filter()
## This means "use the filter function from the dplyr package"
## Notation is used given sometimes different packages have
## the same function name, so it helps code to tell which
## package to use for that particular function.
## The notation is continued even when a function name is
## unique to a particular package so it is obvious which
## package is used

#####################################
#####################################

# Create function that will pull data from publicly available websites
## This allows for the analyis to have the most current data; for some
## of the datasets are updated with periodical frequency (e.g., every 
## month) or when needed. Additionally, this keeps consistency with
## naming of files and datasets.
### The function downloads the desired data from the URL provided and
### then unzips the data for use

data_download_function <- function(download_list, data_dir){
  
  # loop function across all datasets
  for(i in 1:length(download_list)){
    
    # designate the URL that the data are hosted on
    url <- download_list[i]
    
    # file will become last part of the URL, so will be the data for download
    file <- basename(url)
    
    # Download the data
    if (!file.exists(file)) {
      options(timeout=1000)
      # download the file from the URL
      download.file(url = url,
                    # place the downloaded file in the data directory
                    destfile = file.path(data_dir, file),
                    mode="wb")
    }
    
    # Unzip the file if the data are compressed as .zip
    ## Examine if the filename contains the pattern ".zip"
    ### grepl returns a logic statement when pattern ".zip" is met in the file
    if (grepl(".zip", file)){
      
      # grab text before ".zip" and keep only text before that
      new_dir_name <- sub(".zip", "", file)
      
      # create new directory for data
      new_dir <- file.path(data_dir, new_dir_name)
      
      # unzip the file
      unzip(zipfile = file.path(data_dir, file),
            # export file to the new data directory
            exdir = new_dir)
      # remove original zipped file
      file.remove(file.path(data_dir, file))
    }
    
    dir <- file.path(data_dir, new_dir_name)
  }
}

#####################################
#####################################

# set directories
## define data directory (as this is an R Project, pathnames are simplified)
data_dir <- "data/a_raw_data"

#####################################
#####################################

# download data

## BOEM wind call areas data
### BOEM source (geodatabase): https://www.boem.gov/renewable-energy/mapping-and-data/renewable-energy-gis-data
### An online download link: https://www.boem.gov/renewable-energy/boem-renewable-energy-geodatabase
### Metadata: https://www.arcgis.com/sharing/rest/content/items/709831444a234968966667d84bcc0357/info/metadata/metadata.xml?format=default&output=html
#### ***Note: Data are also accessible for download on MarineCadastre (under "Active Renewable Energy Leases")
#### This provides a usable URL for R: https://www.boem.gov/BOEM-Renewable-Energy-Geodatabase.zip
boem_wind_area <- "https://www.boem.gov/BOEM-Renewable-Energy-Geodatabase.zip"

#####################################

## constraints

### Bathymetry data
#### Explore data here: https://www.ncei.noaa.gov/maps/bathymetry/
#### On side panel, select "DEM footprints" or "Continuously Updated Digital Elevation Model (CUDEM)" -- CUDEM will often have best resolution
#### Move into area of interest and click within area of interest
#### In pop-up box, scroll over available datasets to see footprints and click best option for analysis (CUDEM)

#### Three options for data download
#### 1.) Bulk down (source: https://coast.noaa.gov/dataviewer/#/lidar/search/where:ID=8580) -- advantage DEMs come as single file
####    a.) Draw boundary box around area of interest
####    b.) Click datasource in pop-up panel on right
####    c.) Click add to cart
####    d.) Navigate to cart by clicking cart symbol in top right
####    e.) Click "Next"
####    f.) Select projection, zone, horizontal datum, vertical datum, and output format
####    g.) Enter e-mail information

#### 2.) Individual download
####    a.) Navigate to correct data page
####      i.) 1/9-arc: https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/
####      ii.) 1/3-arc: https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/

#### 3.) Connect to server
####    a.) Connect to correct server
####      i.) 1/9-arc server connecting link: ftp://ftp.coast.noaa.gov/pub/DigitalCoast/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/
####      ii.) 1/3-arc server connecting link: ftp://ftp.coast.noaa.gov/pub/DigitalCoast/raster2/elevation/NCEI_third_Topobathy_2014_8580/
####    b.) Navigate to correct directory in server
####      i.) 1/9-arc directory: MA_NH_ME
####      i.) 1/3-arc directory: rima

#### Data are spread across two major data sourcs: CUDEM third arc-second resolution and ninth arc-second resolution
#### ***Note: for the 1/9-arc second data (~3m), the data encompass three datasets
####    a.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x00_2018v1.tif,
####    b.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x25_2018v1.tif,
####    c.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x50_2018v1.tif)

#### ***Note: for the 1/3-arc second data (~10m), the data encompass three datasets
####    a.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x00_2021v1.tif
####    b.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x25_2021v1.tif
####    c.) https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x50_2021v1.tif

bath_9th_1 <- "https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x00_2018v1.tif"
bath_9th_2 <- "https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x25_2018v1.tif"
bath_9th_3 <- "https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_ninth_Topobathy_2014_8483/rima/ncei19_n41x50_w071x50_2018v1.tif"

bath_3rd_1 <- "https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x00_2021v1.tif"
bath_3rd_2 <- "https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x25_2021v1.tif"
bath_3rd_3 <- "https://chs.coast.noaa.gov/htdata/raster2/elevation/NCEI_third_Topobathy_2014_8580/MA_NH_ME/ncei13_n41x25_w071x50_2021v1.tif"

#####################################

### Unexploded ordnance location data (source: https://marinecadastre.gov/downloads/data/mc/UnexplodedOrdnance.zip)
#### Metadata: https://www.fisheries.noaa.gov/inport/item/66208
unexploded_ordnance_location <- "https://marinecadastre.gov/downloads/data/mc/UnexplodedOrdnance.zip"

#####################################

### Munitions and explosives of concern data (source: https://marinecadastre.gov/downloads/data/mc/MunitionsExplosivesConcern.zip)
#### Metadata: https://www.fisheries.noaa.gov/inport/item/69013
#### MarineCadastre: https://marinecadastre-noaa.hub.arcgis.com/datasets/c28b230c336b472e979723d15ede22e7_0/about
munitions_explosives <- "https://marinecadastre.gov/downloads/data/mc/MunitionsExplosivesConcern.zip"

#####################################

### Danger zones and restricted areas data (source: https://marinecadastre.gov/downloads/data/mc/DangerZoneRestrictedArea.zip)
#### MarineCadastre: https://marinecadastre-noaa.hub.arcgis.com/datasets/noaa::danger-zones-and-restricted-areas/about
#### Metadata: https://www.fisheries.noaa.gov/inport/item/48876
danger_zone <- "https://marinecadastre.gov/downloads/data/mc/DangerZoneRestrictedArea.zip"

#####################################

### Environmental sensors and buoys data (source: https://www.northeastoceandata.org/files/metadata/Themes/PhysicalOceanography.zip)
#### Metadata: https://www.northeastoceandata.org/files/metadata/Themes/PhysicalOceanography/NERACOOSBuoys.htm
environmental_sensor_buoy <- "https://www.northeastoceandata.org/files/metadata/Themes/PhysicalOceanography.zip"

#####################################

### Wastewater outfall facilities data (source: https://marinecadastre.gov/downloads/data/mc/WastewaterOutfall.zip)
#### MarineCadastre: https://marinecadastre-noaa.hub.arcgis.com/datasets/b0c5d61277f440e3b6ca001f7fbd5416_0/about
#### Metadata: https://www.fisheries.noaa.gov/inport/item/66706
#### ***Note: the download link is the same for the wastewater outfall pipes data (https://marinecadastre-noaa.hub.arcgis.com/datasets/noaa::wastewater-outfall-pipes/about)
####          and the wastewater outfalls data (https://marinecadastre.gov/downloads/data/mc/WastewaterOutfall.zip)
wastewater_outfall <- "https://marinecadastre.gov/downloads/data/mc/WastewaterOutfall.zip"

#####################################

### Ocean disposal sites data (source: https://marinecadastre.gov/downloads/data/mc/OceanDisposalSite.zip)
#### MarineCadastre: https://marinecadastre-noaa.hub.arcgis.com/datasets/noaa::ocean-disposal-sites/about
#### Metadata: https://www.fisheries.noaa.gov/inport/item/54193
ocean_disposal <- "https://marinecadastre.gov/downloads/data/mc/OceanDisposalSite.zip"

#####################################

### Aids to navigation data (source: https://marinecadastre.gov/downloads/data/mc/AtoN.zip)
#### MarineCadastre: https://marinecadastre-noaa.hub.arcgis.com/datasets/noaa::aids-to-navigation-1/about
#### Metadata: https://www.fisheries.noaa.gov/inport/item/56120
aids_navigation <- "https://marinecadastre.gov/downloads/data/mc/AtoN.zip"

#####################################

### Wrecks and obstructions data (source: https://marinecadastre.gov/downloads/data/mc/WreckObstruction.zip)
#### MarineCadastre: https://marinecadastre-noaa.hub.arcgis.com/datasets/noaa::wrecks-and-obstructions/about
#### Metadata: https://www.fisheries.noaa.gov/inport/item/70439
wrecks_obstructions <- "https://marinecadastre.gov/downloads/data/mc/WreckObstruction.zip"

#####################################

### Shipping lanes data (source: http://encdirect.noaa.gov/theme_layers/data/shipping_lanes/shippinglanes.zip)
#### ***Note: These are federal water shipping lanes
#### Metadata: https://www.fisheries.noaa.gov/inport/item/39986
federal_shipping_lanes <- "http://encdirect.noaa.gov/theme_layers/data/shipping_lanes/shippinglanes.zip"


#####################################


## National Security

### Unexploded ordnance area data (source: https://marinecadastre.gov/downloads/data/mc/UnexplodedOrdnanceArea.zip)
#### Metadata: https://www.fisheries.noaa.gov/inport/item/66206
unexploded_ordnance_area <- "https://marinecadastre.gov/downloads/data/mc/UnexplodedOrdnanceArea.zip"

#####################################

### Special use airspace
#### MarineCadastre: https://marinecadastre-noaa.hub.arcgis.com/datasets/noaa::military-special-use-airspace/about
#### Metadata: https://www.fisheries.noaa.gov/inport/item/48898
#### ***Note: Marine Cadastre had a link for special use airspace (https://marinecadastre.gov/downloads/data/mc/MilitarySpecialUseAirspace.zip)
####          yet these data have become deprecated (according to Daniel Marin [daniel.martin@noaa.gov] as of 31 January 2024)

### Military operating areas data (source: https://marinecadastre.gov/downloads/data/mc/MilitaryCollection.zip)
#### Data.gov: https://catalog.data.gov/dataset/military-operating-area-boundaries/resource/50f08bdd-3816-4895-824c-c48e71d9d3d7
#### Metadata: https://www.fisheries.noaa.gov/inport/item/55364
#### ***Note: MarineCadastre contains an alternative download link: https://marinecadastre.gov/downloads/data/mc/MilitaryOperatingAreaBoundary.zip)
####          yet these data contain different objects (as the data were deprecated on 9 February 2024),
####          though both datasets have the same data for the study region
military <- "https://marinecadastre.gov/downloads/data/mc/MilitaryCollection.zip"


#####################################


## Natural and Cultural Resources

### Sediment (source: https://marinecadastre.gov/downloads/data/mc/SedimentTexture.zip)
#### MarineCadastre: https://marinecadastre-noaa.hub.arcgis.com/datasets/noaa::sediment-texture/about
#### Metadata: https://www.fisheries.noaa.gov/inport/item/55364
sediment <- "https://marinecadastre.gov/downloads/data/mc/SedimentTexture.zip"

### Sediment size (source: https://easterndivision.s3.amazonaws.com/Marine/MooreGrant/Sediment.zip)
#### Northeast Ocean Data: https://easterndivision.s3.amazonaws.com/Marine/MooreGrant/SoftSediment.pdf
sediment_size <- "https://easterndivision.s3.amazonaws.com/Marine/MooreGrant/Sediment.zip"

### Deep sea coral


#####################################


## Industry, Transportation, Navigation

### AIS vessel tracks (counts) (source: https://services.northeastoceandata.org/downloads/AIS/AIS2022_Annual.zip)
#### Northeast Ocean data: https://www.northeastoceandata.org/data-download/
#### Metadata: https://www.northeastoceandata.org/files/metadata/Themes/AIS/AllAISVesselTransitCounts2022.pdf
ais_counts <- "https://services.northeastoceandata.org/downloads/AIS/AIS2022_Annual.zip"


#####################################


## Fisheries

### Cod spawning protection areas (source: https://media.fisheries.noaa.gov/2020-04/gom-spawning-groundfish-closures-20180409-noaa-garfo.zip)
#### Metadata: https://media.fisheries.noaa.gov/dam-migration/gom-spawning-groundfish-closures-metadata-noaa-fisheries_.pdf
#### PDF Map: https://media.fisheries.noaa.gov/dam-migration/gom-spawning-groundfish-closures-map-noaa-fisheries_.pdf
cod_protection <- "https://media.fisheries.noaa.gov/2020-04/gom-spawning-groundfish-closures-20180409-noaa-garfo.zip"


#####################################

## Miscellaneous

### Federal waters (https://marinecadastre.gov/downloads/data/mc/CoastalZoneManagementAct.zip)
#### Metadata: https://www.fisheries.noaa.gov/inport/item/53132
federal_waters <- "https://marinecadastre.gov/downloads/data/mc/CoastalZoneManagementAct.zip"

### Temperature (https://marinecadastre.gov/downloads/data/mc/EMUWaterQuality.zip)
#### Metadata: https://www.fisheries.noaa.gov/inport/item/66137
temperature <- "https://marinecadastre.gov/downloads/data/mc/EMUWaterQuality.zip"

### Massachusetts town survey (https://s3.us-east-1.amazonaws.com/download.massgis.digital.mass.gov/gdbs/townssurvey_gdb.zip)
#### Metadata: https://www.mass.gov/info-details/massgis-data-municipalities
mass_admin <- "https://s3.us-east-1.amazonaws.com/download.massgis.digital.mass.gov/gdbs/townssurvey_gdb.zip"

#####################################
#####################################

# Download list
download_list <- c(
  # BOEM wind energy areas
  boem_wind_area,
  
  # bathymetry
  ## 1/9-arc second
  bath_9th_1,
  bath_9th_2,
  bath_9th_3,
  
  ## 1/3-arc second
  bath_3rd_1,
  bath_3rd_2,
  bath_3rd_3,
  
  # unexploded ordnances
  unexploded_ordnance_location,
  unexploded_ordnance_area,
  
  # munitions and explosives
  munitions_explosives,
  
  # danger zones and restrictions
  danger_zone,
  
  # environmental sensors and buoys
  environmental_sensor_buoy,
  
  # wastewater outfall
  wastewater_outfall,
  
  # ocean disposal
  ocean_disposal,
  
  # aids to navigation
  aids_navigation,
  
  # wrecks and obstructions
  wrecks_obstructions,
  
  # shipping lanes
  federal_shipping_lanes,
  
  # military areas
  military,
  
  # sediment
  sediment,
  
  # sediment size
  sediment_size,
  
  # deep-sea coral
  
  # vessel traffic
  ais_counts,
  
  # cod protection
  cod_protection,
  
  # federal waters
  federal_waters,
  
  # temperature (EMU water quality)
  temperature,
  
  # Massachusetts town boundaries
  mass_admin
)
  
data_download_function(download_list, data_dir)

#####################################
#####################################

# list all files in data directory
list.files(data_dir)

#####################################

# create a subdirectory for bathymetry files
dir.create(path = file.path(data_dir, "bathymetry", sep = "/"))

# create a path for the bathymetry directory
bath_dir <- paste(data_dir, "bathymetry", sep = "/")

# grab all the bathymetry files
bathymetry_files <- list.files(data_dir,
                               # pattern for bathymetry data (they all contain ncei while no other data do)
                               pattern = "ncei")

# move all bathymetry files to the bathymetry subdirectory
for(i in 1:length(bathymetry_files)){
  # move from the current raw directory
  file.rename(from = file.path(data_dir, bathymetry_files[i]),
              # and move to the new bathymetry subdirectory
              to = file.path(bath_dir, bathymetry_files[i]))
}

#####################################

# rename cod spawning protection areas directory
get_file_name <- list.files(data_dir,
                            # get the element that has "gom" in it -- gom = Gulf of Maine
                            pattern = "gom")

file.rename(from = file.path(data_dir, get_file_name),
            # rename it to be shorter and more understandable
            to = file.path(data_dir, "cod_spawning_protection_areas"))

# delete unzipped directory without name change
unlink(file.path(data_dir, get_file_name), recursive = T)

#####################################

# examine all subdirectories in data directory
list.files(data_dir)

#####################################
#####################################

# calculate end time and print time difference
print(Sys.time() - start) # print how long it takes to calculate
