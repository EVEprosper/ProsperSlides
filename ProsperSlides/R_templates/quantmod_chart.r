market.query = 'SELECT price_date AS Date,
        volume AS Volume,
        highPrice AS High,
        lowPrice AS Low,
        avgPrice AS Close
    FROM crest_markethistory
    WHERE itemid={itemid} AND
        regionid={region}
    ORDER BY Date DESC'
market.sqldata <- sqlQuery(emd, market.query)
odbcClose(emd)
n <- nrow(market.sqldata)
market.data <- data.table(market.sqldata[1:n-1,])
market.data$Open <- market.sqldata$Close[-1]
low_flag  = quantile(market.data$Low, .25) / 5
high_flag = quantile(market.data$High, .75) * 5
market.data$Low[market.data$Low<=low_flag] <-min(market.data$Open, market.data$Close)
market.data$High[market.data$High>=high_flag] <-max(market.data$Open, market.data$Close)
market.data.ts <- xts(
    market.data[, -1, with=F],
    order.by=market.data[,Date],
    period=7
)
{img_type}(
    '{img_path}',
    width={img_X},
    height={img_Y}
)
chartSeries(
    market.data.ts,
    name='{plot_title}',
    TA='{TA_args}',
    subset='{default_subset}'
)
dev.off()
