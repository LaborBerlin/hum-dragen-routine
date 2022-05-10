#!/usr/bin/env R

tiles <- parallel::mclapply(
  c("1:1101", "1:1128", "1:1436", "1:1451", "1:1457", "1:2124", "2:1101", "2:1128", "2:1436", "2:1451",  "2:1457", "2:2124"),
  function(t) {
    read.delim(paste0("all_unique.dup-ids.", t), sep=":", header=F)
  },
  mc.cores = 12)

#lane bias?
table(unlist(lapply(tiles, function(t) t[,4])))
#-> no

#bottom vs top bias?
table(unlist(lapply(tiles, function(t) t[,5]/2000 < 1)))
#-> yes! 82% duplicated wells in bottom surface

#plot duplicate coordinates
xmax = max(unlist(lapply(tiles, function(t) t[,6])))
ymax = max(unlist(lapply(tiles, function(t) t[,7])))
mats <- parallel::mclapply(
  tiles,
  function(t) {
    m = matrix(0, nrow=round(xmax/5), ncol=round(ymax/5))
    ord = order(t[,6])
    xidx = round(t[ord,6]/5)
    yidx = round(t[ord,7]/5)
    m[cbind(xidx, yidx)] = rle(yidx)$lengths
    return(m)
  },
  mc.cores = 1)

png("dups.png", width=10000, height=10000)
par(mfcol=c(2,6))
invisible(lapply(mats, function(m) {
  image(m, col=rev(heat.colors(2)), xlab="X", ylab="Y", main="Tile 1101 B", useRaster=T)
}))
dev.off()
