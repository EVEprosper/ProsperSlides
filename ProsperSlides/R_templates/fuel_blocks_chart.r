plot.width = {img_width}
plot.height = {img_height}
plot.range = {date_range}
plot.locationid = {locationid}
plot.title = '{plot_title}'
plot.path = '{plot_path}'
industry.fee = {industry_fee}

list.blocks = c(4051, 4246, 4247, 4312)
list.mats = c(
  16274, 17887, 17888, 17889,
  9832, 44, 16272, 16273, 3689, 3683, 9848, 16275)

list.full <- c(list.blocks, list.mats)
date.min <- Sys.Date() - plot.range
plot.typeids.str <- paste(list.full, collapse=',')

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
  'SUM(IF(buy_sell=1, price_best, NULL)) AS `SellOrder` ',
  'FROM snapshot_evecentral ',
  'WHERE locationid=', plot.locationid, ' ',
  'AND typeid IN (', plot.typeids.str, ') ',
  'AND price_date > \'', date.min, '\' ',
  'GROUP BY price_date, price_time, typeid'
)
ec <- sqlQuery(emd, ec.query)
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
ec$SellOrder.smooth <- NA
for(id in list.blocks){{
  prices <- ec$SellOrder[ec$typeid==id]
  smooth <- rollmean(prices, k=24, align='right', fill=NA)
  ec$SellOrder.smooth[ec$typeid==id] <- smooth
}}
ec$variable <- ec$typeid
ec$value <- ec$SellOrder
ec$datetime_str <- as.character(ec$datetime)
pivot <- cast(
  ec,
  datetime ~ variable
)

pivot$block.base <-
  pivot$`9832`* 8.1 +
  pivot$`44` * 3.6 +
  pivot$`16272` * 150.3 +
  pivot$`16273` * 150.3 +
  pivot$`3689` * 3.6 +
  pivot$`3683` * 19.8 +
  pivot$`9848` * 0.9 +
  pivot$`16275` * 18
pivot$block.caldari  <- ((pivot$block.base + pivot$`17888`*399.6) / 40) * (1+industry.fee/100)
pivot$block.gallente <- ((pivot$block.base + pivot$`17887`*399.6) / 40) * (1+industry.fee/100)
pivot$block.minmatar <- ((pivot$block.base + pivot$`17889`*399.6) / 40) * (1+industry.fee/100)
pivot$block.amarr    <- ((pivot$block.base + pivot$`16274`*399.6) / 40) * (1+industry.fee/100)

pivot.merge <- data.frame(
  block.caldari=pivot$block.caldari,
  block.gallente=pivot$block.gallente,
  block.minmatar=pivot$block.minmatar,
  block.amarr=pivot$block.amarr,
  datetime_str=as.character(pivot$datetime)
)
pivot.merge <- melt(
  pivot.merge,
  id.vars=c('datetime_str'),
  measure.vars=c(
    'block.caldari',
    'block.gallente',
    'block.minmatar',
    'block.amarr')
)
pivot.merge$typeName <- NA
pivot.merge$typeName[pivot.merge$variable=='block.caldari'] <- 'Nitrogen Fuel Block'
pivot.merge$typeName[pivot.merge$variable=='block.gallente'] <- 'Oxygen Fuel Block'
pivot.merge$typeName[pivot.merge$variable=='block.minmatar'] <- 'Hydrogen Fuel Block'
pivot.merge$typeName[pivot.merge$variable=='block.amarr'] <- 'Helium Fuel Block'

plot.data <- subset(
  ec,
  typeid %in% list.blocks
)
plot.data <- merge(
  plot.data, pivot.merge,
  by=c('datetime_str', 'typeName')
)
plot.data <- data.frame(
  datetime=plot.data$datetime,
  typeid=plot.data$typeid,
  typeName=plot.data$typeName,
  SellOrder=plot.data$SellOrder,
  SellOrder.smooth=plot.data$SellOrder.smooth,
  BuildCost=plot.data$value.y
)

## Plot Data ##
plot <- ggplot(
  plot.data,
  aes(
    x=datetime,
    y=BuildCost,
    color=typeName
  )
)
plot <- plot + geom_line(
  size=0.9,
  linetype=3
)
plot <- plot + geom_line(
  aes(
    x=datetime,
    y=SellOrder.smooth,
    color=typeName
  ),
  size=1.2,
  data=plot.data
)
plot <- plot + scale_alpha_manual(values=colors.groups)
plot <- plot + scale_color_manual(
    values=c(
      'Oxygen Fuel Block'='#097686',
      'Hydrogen Fuel Block'='#B7090D',
      'Nitrogen Fuel Block'='#2169E0',
      'Helium Fuel Block'='#EA8B25')
)
plot <- plot + scale_y_continuous(
  labels=function(x)sprintf('%.2fK', x/1e3),
  position='right'
)
plot <- plot + theme_dark()
plot <- plot + labs(
  title=plot.title,
  color='Fuel Blocks',
  x='date',
  y='price'
)
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
