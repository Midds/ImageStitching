% TO RUN, VLFEAT MUST FIRST BE INSTALLED ON THE MACHINE
% VLFEAT can be downloaded from http://www.vlfeat.org/download.html or http://www.vlfeat.org/index.html
% once downloaded and unpacked the command below must be ran on each Matlab restart
% run D:\Users\James\Documents\GitHub\ImageStitching\MATLAB\vlfeat-0.9.20/toolbox/vl_setup
% - with the pathway changed to match the vl_setup path
close all;

% images to merge
%imgs = imageDatastore({'im15.jpeg';'im16.jpeg'});
imgs = imageDatastore({'a.jpg';'b.jpg'});

figure;
montage(imgs.Files);
title('Montage');

%im1 = imread('im15.jpeg'); im2 = imread('im16.jpeg');
im1 = imread('a.jpg'); im2 = imread('b.jpg');

%% PREPROCESSING


% make single
% vl_feat requires single precision greyscale image
im1 = im2single(im1);
im2 = im2single(im2);

% make grayscale
if size(im1,3) > 1 
    im1g = rgb2gray(im1); 
else
    im1g = im1;
end

if size(im2,3) > 1
    im2g = rgb2gray(im2);
else
    im2g = im2; 
end

disp('pre-processing done');

%% FINDING SIFT FEATURES AND DESCRIPTORS
% vl_sift uses the vlfeat open source implementation of sift to find
% keypoints [k] and descriptors [d]
[k1,d1] = vl_sift(im1g);
[k2,d2] = vl_sift(im2g);
disp('sift features found');

% MATCH LOCAL DESCRIPTORS
% for each descriptor(key feature) in d1, vl_ubcmatch finds the closest descriptor in d2
% the index gets stored in matches and the distance between in scores
[matches, scores] = vl_ubcmatch(d1, d2);

numMatches = size(matches,2);
disp('matched local descriptors');

%% Draw Some Matching Features
npts = 10;

figure, colormap gray; imagesc(im1);
figure, colormap gray; imagesc(im2);
for i = 1 : npts
    ind1 = matches(1,i);
    ind2 = matches(2,i);

    figure(1);
    plot1 = vl_plotsiftdescriptor(d1(:, ind1),k1(:, ind1));
    set(plot1, 'color', hsv2rgb([i / npts, 1, 1]));
    
    figure(2)
    plot2 = vl_plotsiftdescriptor(d2(:, ind2),k2(:, ind2));
    set(plot2, 'color', hsv2rgb([i / npts, 1, 1]));
end
disp('Matching features done');

%% DISPLAYING MATCHED KEYPOINTS BETWEEN IMAGES
figure;
imagesc(cat(2, im1, im2)) ;
hold on;
plot (k1(1,matches(1,:)), k1(2, matches(1,:)), 'b*');

hold on ;

x1 = k1(1,matches(1,:)) ;
x2 = k2(1,matches(2,:)) + size(im1,2) ;
x3 = k1(2,matches(1,:)) ;
x4 = k2(2,matches(2,:)) ;

connectLine = line([x1 ; x2], [x3 ; x4]) ;
set(connectLine,'linewidth', 1, 'color', 'b') ;

hold on;
temp = k2; %k2 is used later on so temp is needed here
temp(1,:) = k2(1,:) + size(im1,2) ;
plot (temp(1, matches(2,:)), temp(2, matches (2,:)), 'r*');
axis image off ;

disp('Matched features displayed');

% RANSAC VLFEAT

X1 = k1(1:2,matches(1,:)) ; X1(3,:) = 1 ;
X2 = k2(1:2,matches(2,:)) ; X2(3,:) = 1 ;

clear H score ok ;
for t = 1:100
  % estimate homograpyh
  subset = vl_colsubset(1:numMatches, 4) ;
  A = [] ;
  for i = subset
    A = cat(1, A, kron(X1(:,i)', vl_hat(X2(:,i)))) ;
  end
  [U,S,V] = svd(A) ;
  H{t} = reshape(V(:,9),3,3) ;

  % score homography
  X2_ = H{t} * X1 ;
  du = X2_(1,:)./X2_(3,:) - X2(1,:)./X2(3,:) ;
  dv = X2_(2,:)./X2_(3,:) - X2(2,:)./X2(3,:) ;
  ok{t} = (du.*du + dv.*dv) < 6*6 ;
  score(t) = sum(ok{t}) ;
end

[score, best] = max(score) ;
H = H{best} ;
ok = ok{best} ;


%% Mosaicing

box2 = [1  size(im2,2) size(im2,2)  1 ;
        1  1           size(im2,1)  size(im2,1) ;
        1  1           1            1 ] ;
box2_ = inv(H) * box2 ;
box2_(1,:) = box2_(1,:) ./ box2_(3,:) ;
box2_(2,:) = box2_(2,:) ./ box2_(3,:) ;
ur = min([1 box2_(1,:)]):max([size(im1,2) box2_(1,:)]) ;
vr = min([1 box2_(2,:)]):max([size(im1,1) box2_(2,:)]) ;

[u,v] = meshgrid(ur,vr) ;
im1_ = vl_imwbackward(im2double(im1),u,v) ;

z_ = H(3,1) * u + H(3,2) * v + H(3,3) ;
u_ = (H(1,1) * u + H(1,2) * v + H(1,3)) ./ z_ ;
v_ = (H(2,1) * u + H(2,2) * v + H(2,3)) ./ z_ ;
im2_ = vl_imwbackward(im2double(im2),u_,v_) ;

mass = ~isnan(im1_) + ~isnan(im2_) ;
im1_(isnan(im1_)) = 0 ;
im2_(isnan(im2_)) = 0 ;
mosaic = (im1_ + im2_) ./ mass ;

figure ; clf ;
imagesc(mosaic) ; axis image off ;
title('Mosaic') ;


%%




% BUFFER




% %% RANSAC via project original
% [bestHomography, bestInlierCount] = RANSAC(k1,k2,matches);
% disp('Ransac done');
% 
% %% STITCHING
% mosIm2 = stitch (im1,im2,bestHomography);
% figure;
% imagesc(mosIm2);
% disp('stitch done');
% 
% %%
% perc = bestInlierCount*100/size(matches,2);
% % imwrite(mosIm2,'results/goldengate04_05.png');
% %%
% figure;
% clf;
% imagesc(mosIm2);
% axis image off ;
% title('Mosaic') ;
% colormap gray;
% 
% disp('mosaic done');
% 
% %% Cylindrical Mapping
% 
% mosImCyl = stitch_cylinder (im1,im2,bestHomography);
% 
% figure;
% clf;
% imagesc(mosImCyl);
% axis image off ;
% title('Mosaic') ;
% colormap gray;
% 
% disp('cylinder stitch done');
% 
% figure;
% imagesc(mosIm2);
% colormap gray;
% title('Testing final mosaic');
% disp('final done');