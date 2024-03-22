from matplotlib.lines import Line2D
from matplotlib.legend import Legend
Line2D._us_dashSeq    = property(lambda self: self._dash_pattern[1])
Line2D._us_dashOffset = property(lambda self: self._dash_pattern[0])
Legend._ncol = property(lambda self: self._ncols)

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
#import tikzplotlib

#800x800

#top
# alpha_y = 0.5
# a: alpha_x = 0.001
# b: alpha_x = 0.01
# c: alpha_x = 0.1
# d = alpha_x = 0.5

#bottom: alpha_x = alpha_y = 0.001

samples = np.array([
    8,16,32,64,128,256
])
rendertime_a = np.array([
    27.8, 62.9, 142.1, 292.4, 632.2, 1295.1
])
rendertime_b = np.array([
    8.9, 9.4, 9.5, 18.8, 42.9, 102.7
])
rendertime_c = np.array([
    7.4, 7.8, 9.5, 16.3, 34.9, 70.4
])
rendertime_d = np.array([
    8.9, 9.0, 9.9, 18.3, 36.3, 71.8
])

fig, (ax1,ax2) = plt.subplots(2, figsize=(8, 5), sharex=True)
ax2.set_xlabel("Number of samples")
ax1.set_ylabel("Performance in ms")
ax1.yaxis.set_units("ms")
ax1.yaxis.set_major_formatter(ticker.FormatStrFormatter('%dms'))
ax2.set_ylabel("Performance in ms")
ax2.yaxis.set_units("ms")
ax2.yaxis.set_major_formatter(ticker.FormatStrFormatter('%dms'))
ax1.plot(samples, rendertime_b, color='green', marker='.', label="alpha=(0.01,0.5)")
ax1.plot(samples, rendertime_c, color='blue', marker='.', label="alpha=(0.1,0.5)")
ax1.plot(samples, rendertime_d, color='yellow', marker='.', label="alpha=(0.5,0.5)")
ax2.plot(samples, rendertime_a, color='red', marker='.', label="alpha=(0.001,0.5)")
ax2.plot(samples, rendertime_b, color='green', marker='.', label="alpha=(0.01,0.5)")
ax2.plot(samples, rendertime_c, color='blue', marker='.', label="alpha=(0.1,0.5)")
ax2.plot(samples, rendertime_d, color='yellow', marker='.', label="alpha=(0.5,0.5)")
ax1.legend()
ax2.legend()
plt.xticks(np.arange(8, 256, step=16))

fig.tight_layout()
#tikzplotlib.clean_figure(fig)
#tikzplotlib.save("performance_plot.tikz")

plt.show()
