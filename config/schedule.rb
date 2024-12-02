every 1.hour do
    runner "UpdateCoinPricesJob.perform_later"
end
  