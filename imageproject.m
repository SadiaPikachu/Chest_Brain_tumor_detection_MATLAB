clc;
close all;
clear all;

% Show Message Box for Selection
choice = questdlg('What detection do you want to perform?', 'Detection Selection', ...
    'Brain Tumor Detection', 'Chest Tumor Detection', 'Cancel', 'Cancel');

switch choice
    case 'Brain Tumor Detection'
        %% Brain Tumor Detection Code
        [I, path] = uigetfile({'*.*', 'All Image Files'}, 'Select an input image');
        if isequal(I, 0)
            disp('No image selected, exiting...');
            return;
        end
        str = strcat(path, I);
        s = imread(str);
        
        figure;
        imshow(s);
        title('Input Image', 'FontSize', 20);

        %% Filter
        num_iter = 10;
        delta_t = 1/7;
        kappa = 15;
        option = 2;
        disp('Preprocessing image, please wait...');
        inp = anisodiff(s, num_iter, delta_t, kappa, option);
        inp = uint8(inp);

        inp = imresize(inp, [256,256]);
        if size(inp,3) > 1
            inp = rgb2gray(inp);
        end
        figure;
        imshow(inp);
        title('Filtered Image', 'FontSize', 20);

        %% Thresholding
        sout = imresize(inp, [256,256]);
        t0 = 60;
        th = t0 + ((max(inp(:)) + min(inp(:))) / 2);
        sout(inp > th) = 1;
        sout(inp <= th) = 0;

        %% Morphological Operation
        label = bwlabel(sout);
        stats = regionprops(logical(sout), 'Solidity', 'Area', 'BoundingBox');
        density = [stats.Solidity];
        area = [stats.Area];
        high_dense_area = density > 0.6;
        max_area = max(area(high_dense_area));
        tumor_label = find(area == max_area);
        tumor = ismember(label, tumor_label);

        if max_area > 100
            box = stats(tumor_label);
            wantedBox = box.BoundingBox;
        else
            msgbox('No Tumor detected!!', 'Status', 'help');
            return;
        end

        %% Tumor Outline
        dilationAmount = 5;
        rad = floor(dilationAmount);
        [r,c] = size(tumor);
        filledImage = imfill(tumor, 'holes');
        erodedImage = imerode(filledImage, strel('disk', rad));
        tumorOutline = tumor & ~erodedImage;

        %% Insert Outline in Image
        rgb = inp(:,:,[1 1 1]);
        red = rgb(:,:,1); red(tumorOutline) = 255;
        green = rgb(:,:,2); green(tumorOutline) = 0;
        blue = rgb(:,:,3); blue(tumorOutline) = 0;
        tumorOutlineInserted = cat(3, red, green, blue);

        %% Display Results
        figure;
        subplot(231); imshow(s); title('Input Image', 'FontSize', 20);
        subplot(232); imshow(inp); title('Filtered Image', 'FontSize', 20);
        subplot(233); imshow(inp); title('Bounding Box', 'FontSize', 20);
        hold on; rectangle('Position', wantedBox, 'EdgeColor', 'y'); hold off;
        subplot(234); imshow(tumor); title('Tumor Alone', 'FontSize', 20);
        subplot(235); imshow(tumorOutline); title('Tumor Outline', 'FontSize', 20);
        subplot(236); imshow(tumorOutlineInserted); title('Detected Tumor', 'FontSize', 20);

        %% Show Final Message
        msgbox('Tumor Detected!', 'Status', 'warn');

    case 'Chest Tumor Detection'
        %% Chest Tumor Detection Code
        [I, path] = uigetfile({'*.*', 'All Image Files'}, 'Select an input image');
        if isequal(I, 0)
            disp('No image selected, exiting...');
            return;
        end
        str = fullfile(path, I);
        originalImage = imread(str);

        figure(1);
        subplot(2,2,1);
        imshow(originalImage);
        title('Original Image');
        greyScale = im2gray(originalImage);
        subplot(2,2,2);
        imshow(greyScale);
        title('Grey Scale Image');

        %% High-Pass Filter
        kernel = -1 * ones(3);
        kernel(2,2) = 9;
        enhancedImage = imfilter(greyScale, kernel);
        subplot(2,2,3);
        imshow(enhancedImage);
        title('After High-Pass Filter');

        %% Median Filter
        medianFiltered = medfilt2(enhancedImage);
        subplot(2,2,4);
        imshow(medianFiltered);
        title('After Median Filter');

        %% Threshold Segmentation
        BW = imbinarize(medianFiltered, 0.6);
        figure(2);
        subplot(2,2,1);
        imshow(BW);
        title('Threshold Segmentation');

        %% Watershed Segmentation
        I = imresize(originalImage, [200, 200]);
        I = im2gray(I);
        I = im2bw(I, 0.6);
        hy = fspecial('sobel');
        hx = hy';
        Iy = imfilter(double(I), hy, 'replicate');
        Ix = imfilter(double(I), hx, 'replicate');
        gradmag = sqrt(Ix.^2 + Iy.^2);
        L = watershed(gradmag);
        Lrgb = label2rgb(L);
        subplot(2,2,2);
        imshow(Lrgb);
        title('Watershed Segmentation');

        %% Morphological Operations
        se1 = strel('disk', 2);
        se2 = strel('disk', 20);
        first = imclose(BW, se1);
        second = imopen(first, se2);
        subplot(2,2,3);
        imshow(second);
        title('After Morphological Structuring Operations');

        %% Detect Tumor
        stats = regionprops('table', second, 'Centroid', 'MajorAxisLength', 'MinorAxisLength');
        centers = stats.Centroid;
        diameters = mean([stats.MajorAxisLength stats.MinorAxisLength], 2);
        radii = diameters / 2;
        finalRadii = radii + 40;

        if any(radii > 5)
            %% Tumor Found
            K = im2uint8(second);
            final = imadd(K, greyScale);
            figure(3);
            subplot(2,1,1);
            imshow(originalImage,[]);
            title('Original Image');
            subplot(2,1,2);
            imshow(final, []);
            viscircles(centers, finalRadii);
            title('Detected Tumor');
            msgbox('Tumor Detected', 'Detection Result', 'warn');
        else
            %% No Tumor Found
            K = im2uint8(second);
            final=imadd(K, greyScale);
            figure;
            subplot(2,1,1);
            imshow(originalImage);
            title('Original Image');
            subplot(2,1,2);
            imshow(final, []);
            %viscircles(centers,radii);
            title('No Tumor Detected');
            msgbox('No Tumor Detected', 'Detection Result', 'help');
        end

    case 'Cancel'
        disp('Operation Cancelled.');
        return;
end
