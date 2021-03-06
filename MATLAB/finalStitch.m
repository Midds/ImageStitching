%% IMPORTANT %%
% TO RUN, VLFEAT MUST FIRST BE INSTALLED ON THE MACHINE
% VLFEAT can be downloaded from http://www.vlfeat.org/download.html or http://www.vlfeat.org/index.html
% (however, this should already be downloaded and placed in the current
% folder, but the below command still needs to be executed on each Matlab restart)
% "run vlfeat-0.9.20\toolbox\vl_setup"
close all;

% select number of images to stitch
numToStitch = 7;
% select the starting image to stitch (whatever number it is in the file)
% eg if image name = 'im168.jpeg', then startImage = 168
startImage = 168;

% Creating an array to store the images
imArray = {};

% Threshold for Euclidean distance (for finding matches between SIFT descriptors)
% Higher threshold (50+) recommended for images with low match % (barret images)
euclideanThresh = 55;

% modifying numToStitch to be compatible with current implementation
% (needs to be an odd number)
if mod(numToStitch, 2) == 0
    numToStitch = numToStitch - 1;
end

% Reading Images
for n = startImage:(startImage+numToStitch)-1
    filename = sprintf('barret1/im%d.jpeg', n); % defining the filename
    im = imread(filename); % reading the image from the given filename
    % im = imresize(im,1.5); %- suggested but not required for barret1 images (change the number to 1.5 - 2)
    imArray = [imArray im]; % adding the image to the image Array
end

 %showing images to be stitched
 figure;
 newimage = cell2mat(imArray);
 imshow(newimage);
 title('Images to stitch');

% Read the first image from the image set.
im1 = imArray{1};

% preprocessing for im1
im1 = im2single(im1);
% make grayscale
    if size(im1,3) > 1 
        Ig = rgb2gray(im1); 
        Ig = imadjust(Ig);
    else
        Ig = im1;
    end

% finding sift kypoints for im1
% vl_sift uses the vlfeat open source implementation of sift to find
% features F2 and descriptors D2 based on the sift algorithm (Lowe, 2004)
[F2,D2] = vl_sift(Ig);
disp('sift features found for image: 1');

% Now loop through the remaining images
% The nested loop will save a homography matrix (Hn) for each successive image
% pair up until the centre image of the image array. The image array is
% then reversed in order, and the nested loop will go again, looping until
% it hits the centre image again. This is needed as the H matrices need to be created 
% in this direction to successfully stitch them together later.
m = 2;
for j = 1:2
    for n = 2:(numToStitch/2) + 1
        %Store points and features for I(n-1).
        % d1,k1 will then be updated later in the loop to store n
        D1 = D2;
        F1 = F2;
        
        imPrev = Ig;
        
        %% PREPROCESSING
        % read the next image from the image array (starts at image 2 as first image alread read in)
        I = imArray{n};
        % make single
        % vl_feat requires single precision greyscale image
        I = im2single(I);
        
        % making the image grayscale
        if size(I,3) > 1
            Ig = rgb2gray(I);
            Ig = imadjust(Ig);
        else
            Ig = I;
        end
        
        fprintf('pre-processing done for image: %d \n', n);
        fprintf('');
        
        %% FINDING SIFT FEATURES AND DESCRIPTORS
        % returns keypoints and descriptors for image Ig
        [F2,D2] = vl_sift(Ig);
        
        fprintf('sift features found for image: %d\n', n);
        %% MATCHING DESCRIPTORS
        % Kim, M. (2012) ECE661 Homework 5: Sample Solution Using MATLAB. West Lafayette: Perdue University. Available from 
        % https://engineering.purdue.edu/kak/computervision/ECE661_Fall2012/solution/hw5_s1.pdf [Accessed 24 April 2017].
        
        % Nearest neighbour between two sets of descriptors will find the
        % closest descriptor match.
        d = dist(D1',D2); % Distance between D1's column and D2's column
        [Y I] = min(d); % Y I used later on in the L.M algorithm
        count = 0; % Number of non-overlapped correspondences
        c1 = zeros(1,2); % Corresponding feature coordinates of im1 - also used later in the L.M algorithm
        c2 = zeros(1,2); % Corresponding feature coordinates of im2
          
        % Euclidean distance will find a better match than just finding the
        % nearest match. This will compare distances between the first and
        % second nearest neighbour.
        img = [imArray{n-1},imArray{n}];
        for k = 1:length(Y)
            ind = 1; % Indicator to avoid overlapped correspondences
            for l = 1:length(I)
                if l~=k && I(l)==I(k)
                    ind = 0;
                    break;
                end
            end
            if ind && Y(k) < euclideanThresh % Threshold for Euclidean distance
                count = count + 1;
                c1(count,:) = round(F1(1:2,I(k)));
                c2(count,:) = round(F2(1:2,k));
            end
        end
        %% RANSAC algorithm
        % Ransac computes a homography matrix that can then be used to map
        % the coordinates of one image to the coordinates of another image
        % Kim, M. (2012) ECE661 Homework 5: Sample Solution Using MATLAB. West Lafayette: Perdue University. Available from 
        % https://engineering.purdue.edu/kak/computervision/ECE661_Fall2012/solution/hw5_s1.pdf [Accessed 24 April 2017].
        nc = 6; % Number of correspondences used to find a homography
        N = fix(log(1-.99)/log(1-(1-.1)^nc)); % Number of trials by 10% rule
        M = fix((1-.1)*count); % Minimum size for the inlier set
        d_min = 1e100;
        for o = 1:N
            lcv = 1; % Loop control variable
            while lcv % To avoid repeated selection
                r = randi(count,nc,1);
                r = sort(r);
                for k = 1:nc-1
                    lcv = lcv*(r(k+1)-r(k));
                end
                lcv = ~lcv;
            end
            A = zeros(2*nc,9);
            for k = 1:nc
                A(2*k-1:2*k,:)=...
                    [0,0,0,-[c1(r(k),:),1],c2(r(k),2)*[c1(r(k),:),1];
                    [c1(r(k),:),1],0,0,0,-c2(r(k),1)*[c1(r(k),:),1]];
            end
            [U,D,V] = svd(A);
            h = V(:,9);
            H = [h(1),h(2),h(3);h(4),h(5),h(6);h(7),h(8),h(9)];

            d2 = zeros(count,1); % d^2(x_measured, x_true)
            for k = 1:count
                x_true = H*[c1(k,:),1]'; % x_true in HC
                temp = x_true/x_true(3);
                x_true = temp(1:2); % x_true in image plane
                d = c2(k,:)-x_true';
                d2(k) = d(1)^2+d(2)^2;
            end
            [Y I] = sort(d2);
            if sum(Y(1:M)) < d_min
                d_min = sum(Y(1:M));
                inliers = I(1:M);
                outliers = I(M+1:end);
            end
        end

        %% Linear Least Squares 
        A = zeros(2*M,9);
        for k = 1:M
            A(2*k-1:2*k,:)=...
                [0,0,0,-[c1(inliers(k),:),1],c2(inliers(k),2)*[c1(inliers(k),:),1];
                [c1(inliers(k),:),1],0,0,0,-c2(inliers(k),1)*[c1(inliers(k),:),1]];
        end
        [U,D,V] = svd(A);
        h1 = V(:,9); % Homography estimated by LLS with all inliers
        % Non-linear Least Square (Levenberg-Marquardt)
        c1 = c1(inliers,:)';
        c1 = c1(:);
        c2 = c2(inliers,:)';
        c2 = c2(:);
        opt = optimset('Algorithm','levenberg-marquardt');
        h2 = lsqcurvefit(@fun,h1,c1,c2,[],[],opt); % Refined homography by Levenberg-Marquardt
        H = [h2(1),h2(2),h2(3);h2(4),h2(5),h2(6);h2(7),h2(8),h2(9)];

            fprintf('Saving H matrix for im%d and im%d\n',m-1, m);

            %name = ['H', string(m-1), '_', string(m)];
            s = sprintf('%d', m-1);
            name = ['homography/H', s];
            save(char(name) , 'H');

            if (m > numToStitch/2)
                m = m - 1;
            else
                m = m + 1;
            end
        
    end
    % now flip the order of the image array
    % the inner for loop will now loop again, getting H values starting
    % from the end of the array and working towards the centre.
    imArray = fliplr(imArray);
    
     % Read the first image from the image set.
    im1 = imArray{1};
    
    % preprocessing for im1
    im1 = im2single(im1);
    % make grayscale
    if size(im1,3) > 1
        Ig = rgb2gray(im1);
    else
        Ig = im1;
    end
    
    % finding sift kypoints for im1
    % vl_sift uses the vlfeat open source implementation of sift to find
    % features F2 and descriptors D2 based on the sift algorithm (Lowe, 2004)
    [F2,D2] = vl_sift(Ig);
    disp('sift features found for image: 1');
    
    
    m=numToStitch; % m is used in the inner loop to keep track of which images to save
end

%some variables needed later
[M,N,C] = size(imArray{2});

fprintf('imreads done \n');

% Load estimated and refined homographies in previous steps.
% All the refined homographies were saved as mat files.
% preallocating array to hold H
HArray{1, (numToStitch-1)} = [];
% the above loop will always save 1 less Homography than numImages, so this
% will loop from 1:numToStitch-1.
for n = 1:(numToStitch-1)
    s = sprintf('%d', n);   
    name = ['homography/H', s];
    HArray{n} = load(char(name)); 
    HArray{n} = HArray{n}.H;
end

fprintf('Homography matrices loaded \n');

%% HOMOGRAPHY CALCULATION
% Example homography order using 9 images (for easier visualisation)
% This shows how to create a homography H to get from each image to the
% centre image by multiplying the other homographies.
% H15 represents the homography between images 1 and 5, and so forth.
% im1 im2 im3 im4 im5 im6 im7 im8 im9 = order of images
% H15 = H12*H23*H34*H45
% H25 = H23*H34*H45
% H35 = H34*H45
% H45 - created in the loop earlier
% H65 - created in the loop earlier
% H75 = H76*H65
% H85 = H87*H76*H65
% H95 = H98*H87*H76*H65

% Using the above example as a template, this is performed on any number of
% images using the below loops.

% there is always 3 less homographies to create than numImages
% 2 arrays are needed, one for the inwards homographies, one for outwards homographies
HxArray = cell(1,(numToStitch-3)/2); % creates an empty (1 x numToStich-3) cell array 
HxArray2 = cell(1,(numToStitch-3)/2);

m = numToStitch/2;
o = 1;
for n = 1:(numToStitch-3)/2
    HxArray{n} = 1;
    for i = o:m
        HxArray{n} = HxArray{n} * HArray{i};
    end
    o = o + 1;
    fprintf('\nFirst loop ended');
        
end
HArray = fliplr(HArray); % flip array and loop again 
o = 1;
for n = 1:(numToStitch-3)/2
    HxArray2{n} = 1;
    for i = o:m
        HxArray2{n} = HxArray2{n} * HArray{i};
    end
    o = o + 1;
    fprintf('\nFirst loop ended');
        
end

% flip HxArray2 so it's in the right order
HxArray2 = fliplr(HxArray2);

% add the two unmultipled H matrices in the correct places
HxArray = [HxArray,HArray{(size(HArray, 2)/2)+1}];
HxArray2 = [HArray{(size(HArray, 2)/2)}, HxArray2];

% concatenating the 2 arrays into one
HxFinal = [HxArray, HxArray2];

fprintf('Homography matrices multiplied\n');

HxxArray{1, (numToStitch-1)} = [];

tempHFirst = HxFinal{1}'; tempHFirst = tempHFirst(:); %Change first homograpy to a vector form.
tempHFinal = HxFinal{size(HxFinal, 2)}'; tempHFinal = tempHFinal(:); %Change last homograpy to a vector form.

c14 = fun(tempHFirst,[1,1,N,1,1,M,N,M]); % Transformed boundaries of the first image
c74 = fun(tempHFinal,[1,1,N,1,1,M,N,M]); % Transformed boundaries of the last image
fprintf('boundaries found\n');

% used for creating the boundary image
x = [1,3,5,7];
y = [2,4,6,8];
xmin = round(min([c14(x);c74(x)]));
xmax = round(max([c14(x);c74(x)]));
ymin = round(min([c14(y);c74(y)]));
ymax = round(max([c14(y);c74(y)]));

fprintf('minmax boundary done\n');

%% Assign pixels to create the final mosaic %%
img = zeros(ymax-ymin+1,xmax-xmin+1,C); % Create boundary black image
fprintf('assigned zeros done\n');
direction = 'forward';
m = numToStitch;
n = 1;
% using homography matrices to transform image coordinates of each image
% onto the black plane
for i = 1:numToStitch
    if (strcmp(direction ,'forward') == 1)
        img = mosaic(img,imArray{n},HxFinal{n},xmin,ymin);

        fprintf('mosaic im%d\n', n);
        direction = 'backward';
        n = n + 1;
    else
        img = mosaic(img,imArray{m},HxFinal{m-1},xmin,ymin);
        fprintf('mosaic im%d\n', m);
        direction = 'forward';
        m = m - 1;
    end  
end

img(2-ymin:M+1-ymin,2-xmin:N+1-xmin,:) = imArray{ ((size(imArray,2)/2)+0.5) }; % Mosaicking last image
fprintf('Done\n');
figure; imshow(img); title('final');