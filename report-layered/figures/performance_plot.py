from matplotlib.lines import Line2D
from matplotlib.legend import Legend
Line2D._us_dashSeq    = property(lambda self: self._dash_pattern[1])
Line2D._us_dashOffset = property(lambda self: self._dash_pattern[0])
Legend._ncol = property(lambda self: self._ncols)

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
#import tikzplotlib

resolutions = np.array([
    1920*1052,
    800*600,
    830*595,
    525*334,
    350*224,
    1920*1007,
    1776*647,
    1162*950,
    1543*962
])
ggx = np.array([
    5.45, 1.31, 1.35, 0.49, 0.23, 5.23, 3.12, 2.93, 4.02
])
layered = np.array([
    10.23, 3.91, 4.35, 1.5, 0.74, 11.34, 10.73, 11.23, 10.67
])

# sort
idx = np.argsort(resolutions)
resolutions = resolutions[idx]
ggx = ggx[idx]
layered = layered[idx]


fig, (ax1, ax2) = plt.subplots(2, figsize=(8, 5), sharex=True)
ax2.set_xlabel("Resolution in total pixel count")
ax1.set_ylabel("Performance in ms")
ax1.yaxis.set_units("ms")
ax2.set_ylabel("Relation to GGX")
ax1.yaxis.set_major_formatter(ticker.FormatStrFormatter('%dms'))
ax2.yaxis.set_major_formatter(ticker.FormatStrFormatter('$%d\\times$'))

ax1.plot(resolutions, layered, color='purple', marker='.', label="Layered")
ax1.plot(resolutions, ggx, color='blue', marker='.', label="GGX")
ax1.legend()

ax2.plot(resolutions, layered / ggx, color='orange', marker='.')
#ax2.axline((0,10), slope=0, color='darkorange', linestyle="--")
ax2.plot([resolutions[0], resolutions[-1]], [2.9, 2.9], color='darkorange', linestyle="--")

fig.tight_layout()
#tikzplotlib.clean_figure(fig)
#tikzplotlib.save("performance_plot.tikz")

sum = 0
for i in range(resolutions.shape[0]):
    sum += layered[i] / ggx[i]
print(sum/resolutions.shape[0])

plt.show()
