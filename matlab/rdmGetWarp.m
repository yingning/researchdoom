function [u1,v1] = rdmGetWarp(frame1, frame2)
%RDBGETWARP  Get warp between two frames.
%   [U,V] = RDMGETWARP(FRAME1, FRAME2) returns the arrays U,V
%   containing the horiziontal and verical location of each pixel
%   of FRAME2 in FRAME1. This is estimated from the depth map and
%   egomotion. As such, results are not correct for sprites (which are
%   flat) and moving objects.

% Copyright (c) 2016 Andrea Vedaldi

% Get 3D transformation from camera 2 back to camera 1.
A1 = getPlayerTransform(frame1) ;
A2 = getPlayerTransform(frame2) ;
A = inv(A1)*A2 ;

% Camera matrix.
% From the Doom source code, the FOV is computed as follows:
%   ANG180 = sscanf('80000000','%x')  ;
%   ANGLETOFINESHIFT = 19 ;
%   FIELDOFVIEW = 2048 ;
%   doomFov = FIELDOFVIEW / (ANG180/2^ANGLETOFINESHIFT) * pi ;
%
% Note that Doom seem to shift the view center slightly w.r.t.
% the image center, as the optical center is at pixel W/2+1.
%
% Finally, there is a small correction for the scale due to the fact
% that doom shifts all angles by a tiny amount when computing the tangent
% tables.

doomFov = pi/2 ;
W = size(frame2.depthmap,2) ;
H = size(frame2.depthmap,1) ;
scale = tan(doomFov/2) / (W/2) * 1.0007 ;
K = diag([scale -scale 1]) * ...
  [1 0 -W/2-1 ; 
   0 1 -H/2-1 ;
   0 0 1    ] ;
iK = inv(K) ;

% Get pixel coordinates in 3D space.
[u2,v2] = meshgrid(1:W,1:H) ;
x2 = K(1,1) * u2 + K(1,2) * v2 + K(1,3) ;
y2 = K(2,1) * u2 + K(2,2) * v2 + K(2,3) ;

% Get 3D points in camera 2.
depth = single(frame2.depthmap) / 2^6 ;
X2 = x2 .* depth ;
Y2 = y2 .* depth ;
Z2 = depth ;

% Get 3D points in camera 1.
X1 = A(1,1) * X2 + A(1,2) * Y2 + A(1,3) * Z2 + A(1,4) ;
Y1 = A(2,1) * X2 + A(2,2) * Y2 + A(2,3) * Z2 + A(2,4) ;
Z1 = A(3,1) * X2 + A(3,2) * Y2 + A(3,3) * Z2 + A(3,4) ;

% Project on image 1.
x1 = X1 ./ Z1 ;
y1 = Y1 ./ Z1 ;
u1 = iK(1,1) * x1 + iK(1,2) * y1 + iK(1,3) ;
v1 = iK(2,1) * x1 + iK(2,2) * y1 + iK(2,3) ;

% Debug.
if 0
  figure(100) ; clf ;
  depth1 = single(frame1.depthmap) / 2^6 ;
  X1_ = x2 .* depth1 ;
  Y1_ = y2 .* depth1 ;
  Z1_ = depth1 ;
  plot3(X1(:),Y1(:),Z1(:),'r.') ; hold on ;
  plot3(X1_(:),Y1_(:),Z1_(:),'g.') ;
  axis equal ;
end

function A = getPlayerTransform(frame)
T = frame.player.position ;
r = frame.player.orientation - pi/2 ;
A = [
  cos(r)  0 -sin(r)  T(1) ;
  0       1       0  T(3) ;
  sin(r)  0  cos(r)  T(2) ;
  0       0       0  1] ;