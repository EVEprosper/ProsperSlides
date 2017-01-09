plot.width = {img_width}
plot.height = {img_height}
plot.range = {date_range}
plot.typeid = {itemid}
plot.locationid = {locationid}
plot.title = '{plot_title}'
plot.path = '{plot_path}'

date.min <- Sys.Date() - plot.range

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
if(nrow(event)==0){{
    do_lines <- FALSE
}}

## Get Data ##
ec.query <- paste0(
    'SELECT price_date AS `date`, price_time AS `hour`, locationid, typeid, ',
    'SUM(IF(buy_sell=1, price_best,0)) AS `SellOrder`, ',
    'SUM(IF(buy_sell=1, order_volume,0)) AS `SellVolume`, ',
    'SUM(IF(buy_sell=0, price_best,0)) AS `BuyOrder`, ',
    'SUM(IF(buy_sell=0, order_volume,0)) AS `BuyVolume`',
    'FROM snapshot_evecentral ',
    'WHERE typeid=', plot.typeid, ' ',
    'AND price_date > \'', date.min, '\' ',
    'AND locationid=', plot.locationid, ' ',
    'GROUP BY price_date, price_time, typeid, locationid'
)
ec <- sqlQuery(emd, ec.query)
odbcClose(emd)
ec$date <- as.Date(ec$date)
ec$typeid <- as.factor(ec$typeid)
ec <- subset(ec, SellOrder > 0)
ec$datetime <- paste(ec$date, ec$hour, sep=' ')
ec$datetime <- as.POSIXlt(ec$datetime, tz='GMT')

## CREST lookups ##
CREST_BASE = 'https://crest-tq.eveonline.com/'
solarsystem.addr <- paste0(CREST_BASE, 'solarsystems/', plot.locationid, '/')
solarsystem.json <- fromJSON(readLines(solarsystem.addr))
solarsystem.name <- solarsystem.json$name

type.addr <- paste0(CREST_BASE, 'inventory/types/', plot.typeid, '/')
type.json <- fromJSON(readLines(type.addr))
type.name <- type.json$name

ec$locationName <- solarsystem.name
ec$typeName <- type.name

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
plot.data <- subset(ec, typeid==plot.typeid & locationid==plot.locationid) #FIXME: extra?
plot.data$SellOrder[plot.data$SellOrder <= 0] <- NA
plot.data <- melt.data.frame(
    plot.data,
    id.vars=c(
        'datetime',
        'typeName',
        'typeid'),
    measure.vars=c(
        'SellOrder',
        'BuyOrder',
        'BuyVolume',
        'SellVolume')
)
plot.data$facet[plot.data$variable %in% c('SellOrder', 'BuyOrder')] <- 'price'
plot.data$facet[plot.data$variable %in% c('BuyVolume', 'SellVolume')] <- 'volume'
plot.data.price <- subset(plot.data, facet=='price')
plot.data.volume <- subset(plot.data, facet=='volume')

price.max_scale = max(plot.data.price$value, na.rm=TRUE)
price.min_scale = min(plot.data.price$value, na.rm=TRUE)
volume.max_scale = max(plot.data.volume$value, na.rm=TRUE)
volume.min_scale = min(plot.data.volume$value, na.rm=TRUE)

## Build Plot ##
plot.data.price[order(plot.data.price$datetime),]
plot.price <- ggplot(
    plot.data.price,
    aes(
        x=datetime,
        y=value,
        color=variable)
)
plot.price <- plot.price + geom_line(size=rel(1.2))
plot.price <- plot.price + labs(
    title=plot.title,
    x='date',
    y='price',
    color='key'
)
if(do_lines){{
    plot.price <- plot.price + geom_vline(
        xintercept=as.numeric(event$datetime),
        linetype=2,
        color='white'
    )
    plot.price <- plot.price + geom_text(
        aes(
            x=datetime,
            y=Inf,
            label=eventName),
        color='white',
        angle=-90,
        vjust=1.2,
        hjust=0,
        data=event
    )
}}
if(price.max_scale > 1e9){{
    plot.price <- plot.price + scale_y_continuous(
        limit=c(price.min_scale, NA),
        labels=function(x)sprintf('%.2fB', x/1e9),
        position='right'
    )
}}else if(price.max_scale > 1e6){{
    plot.price <- plot.price + scale_y_continuous(
        limit=c(price.min_scale, NA),
        labels=function(x)sprintf('%.2fM', x/1e6),
        position='right'
    )
}}else if(price.max_scale > 1e3){{
    plot.price <- plot.price + scale_y_continuous(
        limit=c(price.min_scale, NA),
        labels=function(x)sprintf('%.2fK', x/1e3),
        position='right'
    )
}}else{{
    plot.price <- plot.price + scale_y_continuous(
        position='right'
    )
}}
plot.price <- plot.price + theme_dark()
plot.price <- plot.price + scale_color_manual(
    values=c(
        'BuyOrder'='#B7090D',
        'SellOrder'='#2169E0')
)

plot.data.volume[order(plot.data.volume$datetime),]
plot.volume <- ggplot(
    plot.data.volume,
    aes(
        x=datetime,
        y=value,
        color=variable)
)
plot.volume <- plot.volume + geom_line(size=rel(1.2))
plot.volume <- plot.volume + labs(
    x='date',
    y='volume',
    color='key'
)
if(do_lines){{
    plot.volume <- plot.volume + geom_vline(
        xintercept=as.numeric(event$datetime),
        linetype=2,
        color='white'
    )
}}
if(volume.max_scale > 1e9){{
    plot.volume <- plot.volume + scale_y_continuous(
        limit=c(volume.min_scale, NA),
        labels=function(x)sprintf('%.2fB', x/1e9),
        position='right'
    )
}}else if(volume.max_scale > 1e6){{
    plot.volume <- plot.volume + scale_y_continuous(
        limit=c(volume.min_scale, NA),
        labels=function(x)sprintf('%.2fM', x/1e6),
        position='right'
    )
}}else if(volume.max_scale > 1e3){{
    plot.volume <- plot.volume + scale_y_continuous(
        limit=c(volume.min_scale, NA),
        labels=function(x)sprintf('%.2fK', x/1e3),
        position='right'
    )
}}else{{
    plot.volume <- plot.price + scale_y_continuous(
        position='right'
    )
}}
plot.volume <- plot.volume + theme_dark()
plot.volume <- plot.volume + scale_color_manual(
    values=c(
        'BuyVolume'='#B7090D',
        'SellVolume'='#2169E0')
)

plot.combined <- plot_grid(
    plot.price, plot.volume,
    ncol=1,
    align='v'
)

## Print Plot To File ##
png(
    plot.path,
    width=plot.width,
    height=plot.height
)
print(plot.combined)
dev.off()
