clear;
% Uncomment obj, centreThresh, rightThresh, edge detector for Project video
% or Challenge video respectively

% Please make sure the path is provied accoring to your local system.
% Suggestion would be to copy the videos into your main folder.
obj = VideoReader('project_video.mp4');
% obj = VideoReader('challenge_video.mp4');

nframes = obj.NumberOfFrames;

testI = read(obj,71);
newFrames = zeros([size(testI,1) size(testI,2) 3 nframes], class(testI));

% used for predicting angles in the end
centreThresh = 634; rightThresh = 648;   %for project video
% centreThresh = 634; rightThresh = 660;             %for challenge video

for k = 1:nframes  
  
    rgbI = read(obj,k);
  
    newFrames(:,:,:,k) = rgbI;

    [r,c,channel]=size(rgbI);
    midrow = r/2;
   
    I=rgb2gray(rgbI);
    
    % Use Canny for project video and Sobel for challenge video
    bw = edge(I,'Canny',0.5);
%     bw = edge(I,'Sobel',[]);
   
    
    bw = imfilter(bw, [-1 0 1;-1 0 1;-1 0 1]');
    % mask
    bw(1:midrow,:) = 0;
    
    bw = medfilt2(bw);
    
    se = strel('line',5,45);
    bw = imdilate(bw,se);

    % find lines using hough transform
    [H,T,R] = hough(bw);
    P  = houghpeaks(H,10,'threshold',ceil(0.3*max(H(:))));
    lines = houghlines(bw,T,R,P,'FillGap',5,'MinLength',7);
    
    leftLineXL=[];leftLineXR=[];leftLineYL=[];leftLineYR=[];
    rightLineXL=[];rightLineXR=[];rightLineYL=[];rightLineYR=[];
    
    idxL=0;
    idxR=0;
    
    min_len = 100;
    
    for i = 1:length(lines) %or P
       % Determine the endpoints of the longest line segment
       
       len = norm(lines(i).point1 - lines(i).point2);
       
       if (len > min_len)
            
           xy = [lines(i).point1; lines(i).point2];

           x1 = xy(1,1);
           y1 = xy(1,2);
           x2 = xy(2,1);
           y2 = xy(2,2);
          
           if(x2~=x1)
               slope = (y2-y1)/(x2-x1);

               if (slope<-0.45)
                  idxL=idxL+1;
                  leftLineXL=[leftLineXL;1]; 
                  leftLineYL = [leftLineYL;slope * (leftLineXL(idxL) - x1) + y1];
                  leftLineYR = [leftLineYR;0.65*r];
                  leftLineXR = [leftLineXR;(leftLineYR(idxL) - leftLineYL(idxL))/slope + leftLineXL(idxL)];
                   
                  %newFrames(:,:,:,k) = insertShape(newFrames(:,:,:,k), 'Line', [leftLineXL(i) leftLineYL(i) leftLineXR(i) leftLineYR(i)], 'LineWidth',2, 'Color', 'green');
               end

              if (slope>0.45)
                  idxR=idxR+1;
                  rightLineXR =[rightLineXR; c];
                  rightLineYR = [rightLineYR;slope * (rightLineXR(idxR) - x1) + y1];
                  rightLineYL = [rightLineYL;0.65*r];
                  rightLineXL = [rightLineXL;-((rightLineYR(idxR) - rightLineYL(idxR))/slope - rightLineXR(idxR))];
                  
                  %newFrames(:,:,:,k) = insertShape(newFrames(:,:,:,k), 'Line', [rightLineXL(idx) rightLineYL(idx) rightLineXR(idx) rightLineYR(idx)], 'LineWidth',2, 'Color', 'green');
              end
          end
       end
    end
    
    if (~isempty(leftLineXL)*~isempty(leftLineYL)*~isempty(leftLineXR)*~isempty(leftLineYR)*~isempty(rightLineXL)*~isempty(rightLineYL)*~isempty(rightLineXR)*~isempty(rightLineYR) > 0)
        p1=[sum(leftLineXL)/idxL sum(leftLineYL)/idxL];
        p2=[sum(leftLineXR)/idxL sum(leftLineYR)/idxL];
        p3=[sum(rightLineXL)/idxR sum(rightLineYL)/idxR];
        p4=[sum(rightLineXR)/idxR sum(rightLineYR)/idxR];
        
        fit1=polyfit([p1(1) p2(1)],[p1(2) p2(2)],1);
        fit2=polyfit([p3(1) p4(1)],[p3(2) p4(2)],1);
        
        x_intersect = fzero(@(x) polyval(fit1-fit2,x),3);
        
        if (x_intersect < centreThresh)
            Direction = 'Left';
        end
        if (x_intersect > centreThresh)
            Direction = 'Straight';
        end
        if (x_intersect > rightThresh)
            Direction = 'Right';
        end
        
        newFrames(:,:,:,k) = insertShape(newFrames(:,:,:,k), 'FilledPolygon', [p1 p2 p3 p4],'Color', [128 0 0], 'Opacity', 0.4);
    else
        newFrames(:,:,:,k) = insertShape(newFrames(:,:,:,k), 'FilledPolygon', [p1 p2 p3 p4],'Color', [128 0 0], 'Opacity', 0.4);
    end
    newFrames(:,:,:,k) = insertText(newFrames(:,:,:,k),[640 610],Direction);
end
 
frameRate = obj.FrameRate;
implay(newFrames,frameRate);

% v = VideoWriter('output_project_video_new_25fps'); %, 'Uncompressed AVI'
% v.FrameRate = frameRate;
% open(v);
% writeVideo(v,newFrames);
% close(v);