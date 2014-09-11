import pstats
p = pstats.Stats('profile.rslt')
p.strip_dirs().sort_stats('cumulative').print_stats(20)
#p.strip_dirs().sort_stats('time').print_stats(20)
p.print_callers(.5, 'deepcopy')
