plot.width = {img_width}
plot.height = {img_height}
plot.range = {date_range}
plot.locationid = {locationid}
plot.title = '{plot_title}'
plot.path = '{plot_path}'

ExtractorID = 40519
InjectorID  = 40520
PLEX_ID     = 29668
MPCT_ID     = 34133
ResculptID  = 34132
typeID_list <- c(29668,34133,34132,40519,40520,44992)
plot.typeids.str <- paste(typeID_list, collapse=',')

PLEX_AUR <- 3500
RMT_AUR  <- 4035 #$20 USD rate
Extractor_AUR <- 800
SP_HR <- 2700
SP_PLEX <- SP_HR * 30 * 24

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
if(nrow(event)==0){{do_lines <- FALSE}}

## Get Data ##
ec.query <- paste0(
    'SELECT price_date AS `date`, price_time AS `hour`, locationid, typeid, ',
    'SUM(IF(buy_sell=1, price_best, NULL)) AS `SellOrder`, ',
    'SUM(IF(buy_sell=0, price_best, NULL)) AS `BuyOrder` ',
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
## PLEX SPLIT ##
ec$SellOrder[ec$typeid==44992] = ec$SellOrder[ec$typeid==44992] * 500
ec$BuyOrder[ec$typeid==44992] = ec$BuyOrder[ec$typeid==44992] * 500
ec$typeid[ec$typeid==44992] = 29668

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
}}

## Mung Data ##
skill.inj <- subset(ec, typeid==InjectorID)
skill.inj$injector.buy <- skill.inj$BuyOrder
skill.inj$injector.sell<- skill.inj$SellOrder
skill.ext <- subset(ec, typeid==ExtractorID)
skill.ext$extractor.buy <- skill.ext$BuyOrder
skill.ext$extractor.sell<- skill.ext$SellOrder
skill.PLX <- subset(ec, typeid==PLEX_ID)
skill.PLX$PLEX.buy <- skill.PLX$BuyOrder
skill.PLX$PLEX.sell<- skill.PLX$SellOrder

skill <- merge(
    skill.inj, skill.ext,
    by=c(
        'locationid',
        'datetime')
)
skill <- merge(
    skill, skill.PLX,
    by=c(
    'locationid',
    'datetime')
)
skill$isk_SP_full.buy <- skill$PLEX.buy / SP_PLEX
skill$isk_SP_full.sell<- skill$PLEX.sell/ SP_PLEX
skill$isk_SP_market.buy <- (skill$injector.buy - skill$extractor.sell) / 500000
skill$isk_SP_market.sell<- (skill$injector.sell- skill$extractor.sell) / 500000

skill.max <- max(c(
    max(skill$isk_SP_market.sell, na.rm=TRUE),
    max(skill$isk_SP_full.sell, na.rm=TRUE)),
    na.rm=TRUE
)
skill.min <- min(c(
    min(skill$isk_SP_market.buy, na.rm=TRUE),
    min(skill$isk_SP_full.buy, na.rm=TRUE)),
    na.rm=TRUE
)
skill.max.date <- max(skill$datetime, na.rm=TRUE)

## Build Plot ##
alpha_group <- c(0.3, 0.3, 1, 0.3)
tics.min <- round_any(
    skill.min,
    100,
    f=floor
)
tics.max <- round_any(
    skill.max,
    100,
    f=ceiling
)
tics <- seq(
    from=tics.min,
    to=tics.max,
    by=50
)
label <- data.frame(
    x=skill.max.date,
    y=skill$isk_SP_full.sell[skill$datetime==skill.max.date],
    label='PLEX-SP PARITY'
)

plot <- ggplot(
    skill,
    aes(
        x=datetime,
        ymin=isk_SP_market.buy,
        ymax=isk_SP_market.sell)
)
plot <- plot + geom_ribbon(fill='#0066ff')
plot <- plot + theme_dark()
plot <- plot + scale_y_continuous(
    breaks=tics,
    position='right'
)
plot <- plot + labs(
    title=plot.title,
    fill='System',
    x='Date',
    y='ISK/SP'
)
plot <- plot + geom_line(
    aes(
        x=datetime,
        y=isk_SP_full.sell),
    color='white',
    linetype=2,
    size=1.5,
    data=skill,
    inherit.aes=FALSE
)
plot <- plot + geom_text(
    aes(
        x=x,
        y=y,
        label=label),
    data=label,
    color='white',
    vjust=-1.25,
    size=5,
    inherit.aes=FALSE)
if(do_lines){{
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
        size=5,
        inherit.aes=FALSE
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
