from matplotlib.lines import Line2D
from matplotlib.legend import Legend
Line2D._us_dashSeq    = property(lambda self: self._dash_pattern[1])
Line2D._us_dashOffset = property(lambda self: self._dash_pattern[0])
Legend._ncol = property(lambda self: self._ncols)

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
#import tikzplotlib

layers = np.array([
    1,2,3,4
])
rendertime = np.array([
    10.2, 11.2, 12.05, 12.92
])

fig, ax1 = plt.subplots(1, figsize=(8, 5), sharex=True)
ax1.set_xlabel("Number of layers")
ax1.set_ylabel("Performance in ms")
ax1.yaxis.set_units("ms")
ax1.yaxis.set_major_formatter(ticker.FormatStrFormatter('%dms'))
ax1.xaxis.get_major_locator().set_params(integer=True)
ax1.plot(layers, rendertime, color='red', marker='.', label="Layered")
ax1.legend()

fig.tight_layout()
#tikzplotlib.clean_figure(fig)
#tikzplotlib.save("performance_plot.tikz")

plt.show()
