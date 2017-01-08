plot.width = {img_width}
plot.height = {img_height}
plot.range = {date_range}
plot.locationid = {locationid}
plot.title = {plot_title}
plot.path = {plot_path}

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
if(nrow(event)==0){do_lines <- FALSE}

## SDE Fetch ##
types.query <- paste0(
    'SELECT conv1.typeid as `typeID`, ',
    'conv1.typename as `typeName`, ',
    'COALESCE(dgm.valueInt, dgm.valueFloat, 0) AS `meta`, ',
    'grp.groupName AS `groupName`, ',
    'conv1.groupID AS `groupID`, ',
    'cats.categoryID AS `categoryID`, ',
    'cats.categoryName AS `categoryName` ',
    'FROM invTypes conv1 ',
    'JOIN invGroups grp ON (conv1.groupID=grp.groupID) ',
    'JOIN invCategories cats ON (grp.categoryID=cats.categoryID) ',
    'LEFT JOIN dgmTypeAttributes dgm ON (conv1.typeid=dgm.typeid AND dgm.attributeid=633) ',
    'WHERE conv1.marketgroupid IS NOT NULL ',
    'AND conv1.published=1 ',
    'AND grp.categoryID IN (6, 7, 8, 18) ',
    'AND ((grp.categoryID in (6, 7, 18) AND COALESCE(dgm.valueInt, dgm.valueFloat, 0) < 8) ',
    '   OR grp.categoryID=8)'
)

mats.query <- paste0(
    'SELECT conv.typeName, ',
    'conv.typeID, ',
    'grp.groupID, ',
    'grp.groupName, ',
    'grp.categoryID, ',
    'cat.categoryName ',
    'FROM invTypes conv ',
    'JOIN invGroups grp ON (grp.groupID=conv.groupID) ',
    'JOIN invCategories cat ON (cat.categoryID=grp.categoryID) ',
    'WHERE conv.marketGroupID IS NOT NULL ',
    'AND conv.published=1 ',
    'AND grp.categoryID IN (4, 43) ',
    'AND grp.groupID NOT IN (428, 712, 886) '
)
types <- sqlQuery(sde, types.query)
mats  <- sqlQuery(sde, mats.query)

list.ships <- types$typeID[types$categoryName=='Ship']
list.mats  <- mats$typeID
list.RMT   <- c(29668,34133,34132,40519,40520)
list.skill <- c(40519,40520)

crest.query <- paste0(
    'SELECT price_date, ',
    'itemid AS `typeID`, ',
    'regionID, ',
    'CONCAT(YEAR(price_date), \'-\', IF(WEEK(price_date)<10, 0, \'\'), WEEK(price_date)) AS `weekNum`, ',
    'volume * avgPrice as `netTrade` ',
    'FROM crest_markethistory ',
    'WHERE price_date > \'', date.min, '\' ',
    'AND regionID=', plot.locationid, ' '
)
crest <- sqlQuery(emd, crest.query)

odbcClose(sde)
odbcClose(emd)

## Mung Data ##
crest <- subset(crest,
    typeID %in% types$typeID |
    typeID %in% list.RMT |
    typeID %in% list.mats
)
crest$RMT <- 0
crest$RMT[crest$typeID %in% list.RMT] <- crest$netTrade[crest$typeID %in% list.RMT]
crest$not_RMT <- 0
crest$not_RMT[!(crest$typeID %in% list.RMT)] <- crest$netTrade[!(crest$typeID %in% list.RMT)]
crest$Ships <-0
crest$Ships[crest$typeID %in% list.ships] <- crest$netTrade[crest$typeID %in% list.ships]
crest$Materials <- 0
crest$Materials[crest$typeID %in% list.mats] <- crest$netTrade[crest$typeID %in% list.mats]
crest$SkillTrade <- 0
crest$SkillTrade[crest$price_date < '2016-02-09'] <- NA
crest$SkillTrade[crest$typeID %in% list.skill] <- crest$netTrade[crest$typeID %in% list.skill]

crest <- subset(crest, price_date < Sys.Date()) #clip "today"
crest <- data.table(crest)
plot.data <- crest[,
    list(
        net_trade=sum(netTrade),
        RMT_trade=sum(RMT),
        NOT_rmt_items=sum(not_RMT),
        ship_trade=sum(Ships),
        skill_trade=sum(SkillTrade),
        material_trade=sum(Materials)),
    by=c('price_date')
]

k = 7
align = 'right'
plot.data$net_trade.smooth <- rollmean(
    plot.data$net_trade,
    k=k,
    align=align,
    na.pad=TRUE
)
plot.data$RMT_trade.smooth <- rollmean(
    plot.data$RMT_trade,
    k=k,
    align=align,
    na.pad=TRUE
)
plot.data$NOT_rmt_items.smooth <- rollmean(
    plot.data$NOT_rmt_items,
    k=k,
    align=align,
    na.pad=TRUE
)
plot.data$ship_trade.smooth <- rollmean(
    plot.data$ship_trade,
    k=k,
    align=align,
    na.pad=TRUE
)
plot.data$skill_trade.smooth <- rollapply(
    plot.data$skill_trade,
    width=k,
    FUN=function(x) mean(x),
    align=align,
    fill=NA
)
plot.data$material_trade.smooth <- rollmean(
    plot.data$material_trade,
    k=k,
    align=align,
    na.pad=TRUE
)
plot.data.melt <- melt.data.frame(
    plot.data,
    id.vars=c('price_date'),
    measure.vars=c(
        'net_trade',
        'RMT_trade',
        'ship_trade',
        'material_trade',
        'NOT_rmt_items',
        'skill_trade')
)
plot.data.smooth <- melt.data.frame(
    plot.data,
    id.vars=c('price_date'),
    measure.vars=grep(
        '.smooth',
        names(plot.data),
        value=TRUE),
    value.name='smoothed'
)

plot.data.melt$Label[plot.data.melt$variable=='net_trade']      <- 'Total Market Trade'
plot.data.melt$Label[plot.data.melt$variable=='RMT_trade']      <- 'RMT Market'
plot.data.melt$Label[plot.data.melt$variable=='ship_trade']     <- 'Ship Market'
plot.data.melt$Label[plot.data.melt$variable=='material_trade'] <- 'Material Market'
plot.data.melt$Label[plot.data.melt$variable=='NOT_rmt_items']  <- 'General Market'
plot.data.melt$Label[plot.data.melt$variable=='skill_trade']    <- 'Skill Trading'

plot.data.smooth$Label[plot.data.smooth$variable=='net_trade.smooth']      <- 'Total Market Trade'
plot.data.smooth$Label[plot.data.smooth$variable=='RMT_trade.smooth']      <- 'RMT Market'
plot.data.smooth$Label[plot.data.smooth$variable=='ship_trade.smooth']     <- 'Ship Market'
plot.data.smooth$Label[plot.data.smooth$variable=='material_trade.smooth'] <- 'Material Market'
plot.data.smooth$Label[plot.data.smooth$variable=='NOT_rmt_items.smooth']  <- 'General Market'
plot.data.smooth$Label[plot.data.smooth$variable=='skill_trade.smooth']    <- 'Skill Trading'

plot.data <- merge(
    plot.data.melt, plot.data.smooth,
    by=c(
        'price_date',
        'Label')
)
plot.data$value <- plot.data$value.x
plot.data$smooth <- plot.data$value.y
plot.data <- plot.data[order(plot.data$price_date),]
plot.data$price_date <- as.POSIXlt(plot.data$price_date, tz='GMT')

#plot.min.log <- floor(10*log(min(plot.data$value, na.rm=TRUE)))/10
#plot.max.log <- floor(10*log(max(plot.data$value, na.rm=TRUE)))/10
plot.min <- round_any(min(plot.data$value, na.rm=TRUE), 1e11, floor)
plot.max <- round_any(max(plot.data$value, na.rm=TRUE), 1e11, floor)

plot.levels <- seq(
    from=1e12,
    to=plot.max,
    by=4e12
)
## Plot Theme ##
theme_dark <- function( ... ) {
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
}

## Build Plot ##
plot <- ggplot(
    plot.data,
    aes(
        x=price_date,
        y=smooth,
        color=Label)
)
plot <- plot + geom_line(size=1.2)
plot <- plot + geom_line(
    linetype=3,
    alpha=0.8,
    data=plot.data,
    aes(
        x=price_date,
        y=value,
        color=Label)
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
plot <- plot + theme_dark()
plot <- plot + scale_y_log10(labels=function(x)sprintf('%.2fT', x/1e12))
plot <- plot + labs(
    title = plot.title,
    x='date',
    y='Net Trade (daily) log-scale'
)

png(
    plot.path,
    width=plot.width,
    height=plot.height
)
print(plot)
dev.off()
