reorder = []
for i in range(15):
    if i%2==0:
        reorder += range(i*20, (i+1)*20)
    else:
        reorder += range((i+1)*20-1,i*20, -1)

print reorder