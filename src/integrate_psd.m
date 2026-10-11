function power = integrate_psd(frequency, density, band)
%INTEGRATE_PSD Integrate a PSD over exact, possibly off-grid band boundaries.
% Frequency is in Hz, density in ADC counts^2/Hz, and output in ADC counts^2.
% Linear interpolation and trapezoids partition adjacent bands consistently.
validateattributes(frequency, {'double'}, {'column', 'real', 'finite', 'nonnegative'});
validateattributes(density, {'double'}, {'column', 'real', 'finite', 'nonnegative'});
validateattributes(band, {'numeric'}, {'vector', 'numel', 2, 'real', 'finite'});
if numel(frequency) < 2 || numel(density) ~= numel(frequency) || ...
        any(diff(frequency) <= 0)
    error('Sloshing:InvalidPSD', 'PSD arrays must have equal length and increasing frequencies.');
end
if band(1) < frequency(1) || band(2) > frequency(end) || band(1) >= band(2)
    error('Sloshing:InvalidIntegrationBand', 'Integration band must lie within the PSD frequency range.');
end
inside = frequency > band(1) & frequency < band(2);
f = [band(1); frequency(inside); band(2)];
p = [interp1(frequency, density, band(1)); density(inside); ...
    interp1(frequency, density, band(2))];
power = trapz(f, p);
end
