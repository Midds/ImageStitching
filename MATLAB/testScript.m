clear; close; clc;
%% Preprocess %%
% Load single images.
im1 = imread('tiger/im168small.jpeg');
im2 = imread('tiger/im169small.jpeg');
im3 = imread('tiger/im170small.jpeg');
im4 = imread('tiger/im171small.jpeg');
im5 = imread('tiger/im172small.jpeg');
im6 = imread('tiger/im173small.jpeg');
im7 = imread('tiger/im174small.jpeg');
[M,N,C] = size(im2);
% Load estimated and refined homographies in previous steps.
% All the refined homographies were saved as mat files.
H12 = load('H12'); H12 = H12.H; % Homography of im1 to im2
H23 = load('H23'); H23 = H23.H; % Homography of im3 to im2
H34 = load('H34'); H34 = H34.H; % Homography of im1 to im2
H54 = load('H54'); H54 = H54.H; % Homography of im3 to im2
H65 = load('H65'); H65 = H65.H; % Homography of im1 to im2
H76 = load('H76'); H76 = H76.H; % Homography of im3 to im2
% im1 im2 im3 im4 im5 im6 im7 <- order of single images : im4 is in center.
H14 = H12*H23*H34;
H24 = H23*H34;
H64 = H65*H54;
H74 = H76*H65*H54;
%% Boundary Condition of Mosaiced Image %%
h14 = H14'; h14 = h14(:); % Change homograpy to a vector form.
h24 = H24'; h24 = h24(:);
h34 = H34'; h34 = h34(:);
h54 = H54'; h54 = h54(:);
h64 = H64'; h64 = h64(:);
h74 = H74'; h74 = h74(:);
c14 = fun(h14,[1,1,N,1,1,M,N,M]); % Transformed boundaries of im1
c74 = fun(h74,[1,1,N,1,1,M,N,M]); % Transformed boundaries of im7
x = [1,3,5,7];
y = [2,4,6,8];
xmin = round(min([c14(x);c74(x)]));
xmax = round(max([c14(x);c74(x)]));
ymin = round(min([c14(y);c74(y)]));
ymax = round(max([c14(y);c74(y)]));
%% Assign pixel values into the mosaiced image %%
img = zeros(ymax-ymin+1,xmax-xmin+1,C); % Initialize mosaiced image
img = mosaic(img,im1,H14,xmin,ymin); % Mosaicking im1
img = mosaic(img,im7,H74,xmin,ymin); % Mosaicking im7
img = mosaic(img,im2,H24,xmin,ymin); % Mosaicking im2
img = mosaic(img,im6,H64,xmin,ymin); % Mosaicking im6
img = mosaic(img,im3,H34,xmin,ymin); % Mosaicking im3
img = mosaic(img,im5,H54,xmin,ymin); % Mosaicking im5
img(2-ymin:M+1-ymin,2-xmin:N+1-xmin,:) = im4; % Mosaicking im4
figure; imshow(img); imwrite(img,'Mosaic_apt');