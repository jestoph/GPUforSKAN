function out = clamp(in,MIN,MAX)

  out = max([in, MIN]);
  out = min([out,MAX]);


end