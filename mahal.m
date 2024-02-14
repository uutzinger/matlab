function d = mahal(Y,X);
% MAHAL Mahalanobis distance.
%   MAHAL(Y,X) gives the Mahalanobis distance of each point in
%   Y from the sample in X.
%
%   The number of columns of Y must equal the number
%   of columns in X, but the number of rows may differ.
%   The number of rows must exceed the number of columns
%   in X.

%   B.A. Jones 2-04-95
%   Copyright (c) 1993-97 by The MathWorks, Inc.
%   $Revision: 2.4 $  $Date: 1997/04/08 15:07:11 $

[rx,cx] = size(X);
[ry,cy] = size(Y);

if cx ~= cy
   error('Requires the inputs to have the same number of columns.');
end

if rx < cx
   error('The number of rows of X must exceed the number of columns.');
end

m = mean(X);
C = X - m(ones(rx,1),:);
[Q,R] = qr(C,0);
R = R./sqrt(rx-1);
ri = R\eye(cx,cx);

M = m(ones(ry,1),:);
if cy == 1
   E = ((Y-M)*ri);
   d = E.*E;
else
   E = ((Y-M)*ri)';
   d = sum(E.*E)';
end
