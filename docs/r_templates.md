#R_templates

To make the show, we have to make graphs.

To make the graphs, we have to use R.

To automate R, we have to use [rpy2](http://rpy2.readthedocs.io/en/version_2.8.x/)

To make this at all managable, we have to use r_templates

## Making r_templates
`.r_template` is a made-up file extension. It's a mix of executable R code and python `.format()`able tags.

Along with these `.r_template` files are `.json` metadata files.  These are used as tags at load-time to configure the R connector from rpy2

This is by no means a "good" idea, but automating away the second largest time-suck in producing the [EVE Prosper Market Show](https://www.youtube.com/user/EVEProsper) we hope to free up time elsewhere.

The hope is in the longer term, when a generic _Prosper Graphing_ package is developed, we can retire the entire rpy2 dependency and remove an EXTREMELY PAINFUL dependency

### Example
`quantmod.r_template`
```r
### Globals ###
typeID = {typeid}
regionID = {regionid}
CREST_URL = 'https://crest-tq.eveonline.com/'

plot.width = {img_width}
plot.height= {img_height}
plot.name = {img_name}
plot.path = paste0({img_path}, '/', plot.name, '.png')

### Fetch info from CREST ###
typeinfo.url <- paste0(CREST_URL, 'inventory/types/', typeID, '/')
typeinfo.json <- fromJSON(readLines(typeinfo.url))
typeinfo.name <- typeinfo.json$name

regioninfo.url <- paste0(CREST_URL, 'regions/', regionID, '/')
regioninfo.json <- fromJSON(readLines(regioninfo.url))
regioninfo.name <- regioninfo.json$name

priceinfo.url <- paste0(CREST_URL, 'market/', regionID, '/history?type=', CREST_URL, 'inventory/types/', typeID, '/')
priceinfo.json <- fromJSON(readLines(priceinfo.url))
marketdata.json <- data.table(priceinfo.json$items)
marketdata <- marketdata.json[, list(
    Date=as.Date(date)[-1],
    Volume=volume[-1],
    High=highPrice[-1],
    Low=lowPrice[-1],
    Close=avgPrice[-1],
    Open=avgPrice
)]
n <- nrow(marketdata)
marketdata <- marketdata[1:n-1]

### Plot Quantmod ###
plot.title <- paste(typeinfo.name, Sys.Date(), regioninfo.name, sep=' - ')
marketdata.xts <- xts(
    marketdata[, -1, with=F],
    order.by=marketdata[, Date],
    period=7
)
png(
    plot.path,
    height=plot.height,
    width=plot.width
)
chartSeries(
    marketdata.xts,
    name=plot.title,
    TA={TA_args},
    subset={subset_range}
)
dev.off()
```

`quantmod.json`
```js
{
    "package_requires":[
        "jsonlite",
        "quantmod",
        "data.table",
    ],
    "package_overrides":{
        "quantmod":{
            "robject_translations":{"skeleton.TA":"skeletonTA"}
        }
    },
    "robjects":[
    ],
    "required_args":[
        "typeid",
        "regionid",
        "img_path",
        "img_width",
        "img_height",
        "img_name",
        "TA_args",
        "subset_range"
    ]
}
```

These two files represent a matched-pair.  The `r_template` file has nearly-perfect executable code (whith `{}` bindings for python to `.format()` over).  The `.json` contains the metadata needed by rpy to properly set up the environment.

This is because rpy2 handles things like object data and `library()` calls.  Otherwise, rpy2 acts like a virtual session that will execute the `.R` script given to it.

**ALL `.r_template` FILES MUST BE PAIRED WITH A MATCHED `.json` FILE***

