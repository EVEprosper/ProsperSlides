plot.width = {img_width}
plot.height = {img_height}
plot.range = {date_range}
plot.typeids = c(29668,34133,34132,40519)
plot.locationid = {locationid}
plot.title = {plot_title}
plot.path = {plot_path}

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
if(nrow(event)==0){do_lines <- FALSE}

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
for(type.index in 1:length(type_list)){
    type.name <- ''
    type.id <- type_list[type.index]
    type.addr <- paste0(CREST_BASE, 'inventory/types/', type.id, '/')
    type.json <- fromJSON(readLines(type.addr))
    type.name <- type.json$name
    ec$typeName[ec$typeid==type.id] <- type.name
}

## Plot Theme ##
theme_dark <- function( ... ) {
  theme(
    text = element_text(color="gray90"),
    title = element_text(size=rel(2),hjust=0.05,vjust=3.5),
    axis.title.x = element_text(size=rel(1),hjust=0.5, vjust=0),
    axis.title.y = element_text(size=rel(1),hjust=0.5, vjust=1.5),
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
    strip.background = element_rect(fill="gray1"),
    strip.text = element_text(size=rel(1.2))
  ) + theme(...)
}

ec <- subset(ec, SellOrder > 0)
plot.data <- ec
plot.data$SellOrder[plot.data$typeid==34132] <- 3.5 * plot.data$SellOrder[plot.data$typeid==34132]
plot.data$BuyOrder[ plot.data$typeid==34132] <- 3.5 * plot.data$BuyOrder[ plot.data$typeid==34132]
plot.data$SellOrder[plot.data$typeid==40519] <- 35/8* plot.data$SellOrder[plot.data$typeid==40519]
plot.data$BuyOrder[ plot.data$typeid==40519] <- 35/8* plot.data$BuyOrder[ plot.data$typeid==40519]

price.max_scale <- max(plot.data$SellOrder, na.rm=TRUE)
price.min_scale <- min(plot.data$BuyOrder, na.rm=TRUE)

## Build Plot ##
alpha_group <- c(1.0,0.3,0.3,0.8)
plot <- ggplot(
    plot.data,
    aes(
        x=datetime,
        ymin=BuyOrder,
        ymax=SellOrder,
        fill=typeName,
        alpha=typeName)
)
plot <- plot + geom_ribbon()
plot <- plot + theme_dark()
plot <- plot + scale_alpha_manual(values=alpha_group)
plot <- plot + scale_y_continuous(
    limit=c(price.min_scale, NA),
    labels=function(x)sprintf('%.1fB', x/1e9),
    position='right'
)
if(do_lines){
    plot <- plot + geom_vline(
        xintercept=as.numeric(event$datetime),
        linetype=2,
        color='white'
    )
    plot <- plot + geom_text(
        aes(
            x=datetime,
            y=Inf,
            label=eventName),
        color='white',
        angle=-90,
        vjust=1.2,
        hjust=0,
        data=event,
        inherit.aes=FALSE
    )
}
plot <- plot + labs(
    title=plot.title,
    color='PriceKey',
    x='date',
    y='price'
)

## Print Plot To File ##
png(
    plot.path,
    width=plot.width,
    height=plot.height
)
print(plot)
dev.off()
