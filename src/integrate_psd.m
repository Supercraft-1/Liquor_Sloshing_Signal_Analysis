function power = integrate_psd(frequency, density, band)
%INTEGRATE_PSD 在精确频段边界上积分 PSD。
% 输入频率单位为 Hz，PSD 为 ADC 计数平方/Hz，输出为 ADC 计数平方。
% 边界线性插值后作梯形积分，使相邻频段连续衔接。
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
