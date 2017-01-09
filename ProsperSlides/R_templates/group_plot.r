plot.width = {img_width}
plot.height = {img_height}
plot.range = {date_range}
plot.typeids = c({itemids})
plot.locationid = {locationid}
plot.title = '{plot_title}'
plot.path = '{plot_path}'
plot.free_y = {plot_free_y}

date.min <- Sys.Date() - plot.range
plot.typeids.str <- paste(plot.typeids, collapse=',')
## Event List ##
event.query <- paste0(
    'SELECT datetime, eventName ',
    'FROM event_list ',
    'WHERE eventGroup in (\'patch\') ',
    'AND datetime > \'', date.min, '\' '
)
event <- sqlQuery(emd, event.query)
event$datetime <- as.POSIXlt(event$datetime, tz='GMT')
do_lines <- TRUE
if(nrow(event)==0){{do_lines <- FALSE}}

## Get Data ##
ec.query <- paste0(
    'SELECT price_date AS `date`, price_time AS `hour`, locationid, typeid, ',
    'SUM(IF(buy_sell=1, price_best,0)) AS `SellOrder`, ',
    'SUM(IF(buy_sell=0, price_best,0)) AS `BuyOrder` ',
    'FROM snapshot_evecentral ',
    'WHERE locationid=', plot.locationid, ' ',
    'AND typeid IN (', plot.typeids.str, ') ',
    'AND price_date > \'', date.min, '\' ',
    'GROUP BY price_date, price_time, typeid'
)
ec <- sqlQuery(emd, ec.query)
odbcClose(emd)
ec$date <- as.Date(ec$date)
ec$typeid <- as.factor(ec$typeid)
ec <- subset(ec, SellOrder > 0)
ec$datetime <- paste(ec$date, ec$hour, sep=' ')
ec$datetime <- as.POSIXlt(ec$datetime, tz='GMT')

## CREST Lookups ##
CREST_BASE = 'https://crest-tq.eveonline.com/'
solarsystem.addr <- paste0(CREST_BASE, 'solarsystems/', plot.locationid, '/')
solarsystem.json <- fromJSON(readLines(solarsystem.addr))
solarsystem.name <- solarsystem.json$name

ec$locationName <- solarsystem.name

type_list <- unique(ec$typeid)
ec$typeName <- NA
for(type.index in 1:length(type_list)){{
    type.name <- ''
    type.id <- type_list[type.index]
    type.addr <- paste0(CREST_BASE, 'inventory/types/', type.id, '/')
    type.json <- fromJSON(readLines(type.addr))
    type.name <- type.json$name
    ec$typeName[ec$typeid==type.id] <- type.name
}}

## Plot Theme ##
theme_dark <- function( ... ) {{
  theme(
    text = element_text(color="gray90"),
    title = element_text(size=rel(2.5),hjust=0.05,vjust=3.5),
    axis.title.x = element_text(size=rel(0.75),hjust=0.5, vjust=0),
    axis.title.y = element_text(size=rel(0.75),hjust=0.5, vjust=1.5),
    plot.margin = unit(c(2,1,1,1), "cm"),
    plot.background=element_rect(fill="gray8",color="gray8"),
    panel.background=element_rect(fill="gray10",color="gray10"),
    panel.grid.major = element_line(colour="gray17"),
    panel.grid.minor = element_line(colour="gray12"),
    axis.line = element_line(color = "gray50"),
    plot.title = element_text(color="gray80"),
    axis.title = element_text(color="gray70"),
    axis.text = element_text(color="gray50",size=rel(1.1)),
    legend.key = element_rect(fill="gray8",color="gray8"),
    legend.background = element_rect(fill="gray8"),
    legend.title = element_text(size=rel(0.6)),
    legend.text = element_text(size=rel(1.1)),
    strip.background = element_rect(fill="#252525"),
    strip.text = element_text(size=rel(1.2))
  ) + theme(...)
}}

## Mung Data ##
plot.data <- melt.data.frame(
    ec,
    id.vars=c(
        'datetime',
        'typeName'),
    measure.vars=c(
        'SellOrder',
        'BuyOrder')
)
price.max_scale <- max(plot.data$value, na.rm=TRUE)
price.min_scale <- min(plot.data$value, na.rm=TRUE)

## Build Plot ##
plot <- ggplot(
    plot.data,
    aes(
        x=datetime,
        y=value,
        color=variable)
)
plot <- plot + geom_line()
if(plot.free_y){{
    plot <- plot + facet_wrap(~typeName, scales='free_y')
}}else{{
    plot <- plot + facet_wrap(~typeName)
}}
plot <- plot + theme_dark()
plot <- plot + labs(
    title=plot.title,
    color='PriceKey',
    x='date',
    y='price'
)
if(do_lines){{
    plot <- plot + geom_vline(
        xintercept=as.numeric(event$datetime),
        linetype=2,
        color='white'
    )
}}
if(price.min_scale > 1e9){{
    plot <- plot + scale_y_continuous(
        limit=c(price.min_scale, NA),
        labels=function(x)sprintf('%.0fB', x/1e9),
        position='right'
    )
}}else if(price.min_scale > 1e6){{
    plot <- plot + scale_y_continuous(
        limit=c(price.min_scale, NA),
        labels=function(x)sprintf('%.0fM', x/1e6),
        position='right'
    )
}}else if(price.min_scale > 1e3){{
    plot <- plot + scale_y_continuous(
        limit=c(price.min_scale, NA),
        labels=function(x)sprintf('%.0fK', x/1e3),
        position='right'
    )
}}else{{
    plot <- plot + scale_y_continuous(
        position='right'
    )
}}

## Print Plot To File ##
png(
    plot.path,
    width=plot.width,
    height=plot.height
)
print(plot)
dev.off()
