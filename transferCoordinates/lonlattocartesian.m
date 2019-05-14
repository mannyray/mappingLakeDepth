clear all; close all;
format long g

%USER MODIFY:
%-------------------------------------------------
curveCount = 1;

outputFileName = 'noisland2.geo';

%FIRST ELEMENT IN curve(Lon|Lat) MUST REPRESENT LAKE OUTLINE.
%ith index curveLon logically matches ith index of curveLat
lonFileName = {'mainLake2Lon.txt', 'island1Lon.txt'};
latFileName = {'mainLake2Lat.txt', 'island1Lat.txt'};

%the bigger element_size, the more coarse the mesh
element_size = 1000;

fileRefCord = fopen('referenceCoord.txt');
%-------------------------------------------------

outputFileID = fopen(outputFileName,'w');


%read in reference coords
referCoord = textscan(fileRefCord,'%f');
lat0 = referCoord{1}(1);
lon0 = referCoord{1}(2);
h0 = 0;




%read in lake curve data:

%store for of all read in data

curveLon = {};%each column is separate data
curveLat = {};

for i=1:curveCount
	latOutline = readInData(latFileName{i});
	lonOutline = readInData(lonFileName{i});
	assert(isequal(size(latOutline),size(lonOutline)));%basic sanity

	curveLon{i} = lonOutline;
	curveLat{i} = latOutline;
end

%relates to mesh size(check printPoints for details of use)    
fprintf(outputFileID,'element_size = %i;\n',element_size);

%variables that is important for GMSH file for element tagging 
startingPoint_point = 1;
startingPoint_spline = 1;
startingPoint_lineLoop = 1;

%keep track of numbers related to different sections of points since
%it takes a series of points to build splines. a series of splines to build
%a line loops. A series of line loops to build a surface.
queueStartingPoint_point = [];
queueStartingPoint_point = [queueStartingPoint_point ,startingPoint_point];
queueStartingPoint_spline = [];
queueStartingPoint_spline = [queueStartingPoint_spline ,startingPoint_spline];
queueStartingPoint_lineLoop = [];
queueStartingPoint_lineLoop = [queueStartingPoint_lineLoop ,startingPoint_lineLoop];



%print points for curves (includes lake outline and islands)
for i=1:curveCount
	startingPoint_point = printPoints(startingPoint_point, curveLat{i}, curveLon{i}, curveLon{i}, lat0, lon0, h0, outputFileID);
	queueStartingPoint_point = [queueStartingPoint_point ,startingPoint_point];
end


%print all the splines sets related to point sets in queue
lenPointSets = size(queueStartingPoint_point);
lenPointSets = lenPointSets(2);
for i=1:lenPointSets-1
	startingPoint_spline = printSplines(startingPoint_spline, queueStartingPoint_point(i), queueStartingPoint_point(i+1)-1,outputFileID);
	queueStartingPoint_spline = [queueStartingPoint_spline ,startingPoint_spline];
end

%print line loops related to spline sets in queue
lenSplineSets = size(queueStartingPoint_spline);
lenSplineSets = lenSplineSets(2);
for i=1:lenSplineSets-1
	startingPoint_lineLoop = printLineLoops(startingPoint_lineLoop,queueStartingPoint_spline(i), queueStartingPoint_spline(i+1)-1,outputFileID);
	queueStartingPoint_lineLoop = [queueStartingPoint_lineLoop ,startingPoint_lineLoop];
end

%print surface. only one surface
printSurface(queueStartingPoint_lineLoop(1:end-1),outputFileID);


fclose(outputFileID);





%returns N X 1 vector:
function [coords] = readInData(fileName)
	fileID = fopen(fileName);
	coords = textscan(fileID,'%f');
	coords = (coords{1});
end


%assuming that latVec's are N X 1 vector
function [nextStartingPoint] = printPoints(startingPoint, latVec, lonVec, hVec, lat0, lon0, h0, fileID)

	[X,Y,Z] = geodetic2ned(latVec,lonVec,hVec, lat0, lon0, h0, wgs84Ellipsoid);

	sizeX = size(X);
	sizeX = sizeX(1);
	fprintf(fileID,'// Printing points from %i to %i.\n',startingPoint, startingPoint + sizeX - 1);
	for i=1:sizeX
		fprintf(fileID,'Point(%i) = {%f, %f, 0, element_size};\n', i-1+startingPoint, X(i),Y(i));
	end
	fprintf(fileID,'\n\n');
	nextStartingPoint = startingPoint + sizeX;
end

%For a series of points print spline function definition. When put
%together, the spline functions define a closed curve. Each spline printed
%is of the form: 
%Spline(startingPointSpline+i) = { startingPoint+k, ...,startingPoint+k+j};
%Where i is the i'th spline printed in current function call and k is
%current point being processed as part of spline and j is the
%elementsPerSpline (exceptions for last i when the amount of points used in
%splines definitions do not fit evenly ~ this a potentially buggy area).
%INPUT:
%	startingPointSpline: The first value of X printed in Spline(X) = ...
%	startingPoint: The first point of points to be added to splines
%	endingPoint: the last point to be added to splines (assuming the rest
%	of the points to be added lie between startingPoint and endingPoint)
%OUTPUT:
%	nextStartingPointSpline: startingPointSpline + i, where i is the
%	maximum i achieved.
function [nextStartingPointSpline] = printSplines(startingPointSpline, startingPoint, endingPoint, fileID)
	%points per spline curve approximation. The points between
	%startingPoint and endingPoint get cut into elementsPerSpline sized
	%splines (except last spline potentially). The splines put together
	%should form one big curve.
	%NOTE: if you increase elementsPerSpline then that increases potential
	%instability due to nature of spline and might cause your overall curve
	%to form loops/knots which will cause GMSH to crash later on when
	%creating mesh as you cant have a self intersecting curve.
	elementsPerSpline= 3;%change at own risk
	splineCounter = 0;
	
	%this provides the ground for code modification (if the elements you
	%want to be modelled in spline don't fit between startingPoint and
	%endingPoint ~ would just have to pass in the points vector in that
	%case)
	points = startingPoint:endingPoint;
	points = [points, startingPoint];%curve must loop back for GMSH
	
	%indeces representing elementsPerSpline sized window which we are
	%processing 'points' by
	pointsWindowStart = 1;
	
	fprintf(fileID, '// Printing Spline points %i to %i.\n', startingPoint, endingPoint);
	while points(pointsWindowStart) < endingPoint - (elementsPerSpline)
		fprintf(fileID,'Spline(%i) = {',startingPointSpline+splineCounter);
		
		for j=1:elementsPerSpline-1
			fprintf(fileID,'%i,', points(pointsWindowStart+j-1));
		end
		fprintf(fileID, '%i};\n', points(pointsWindowStart+elementsPerSpline-1));
		
		%for curve continuity, current spline has to end where next spline
		%picks up. (hence the minus one )
		pointsWindowStart = pointsWindowStart + elementsPerSpline -1;
		splineCounter = splineCounter + 1;
	end
	
	fprintf(fileID, 'Spline(%i) = {',startingPointSpline+splineCounter);
	for j=points(pointsWindowStart):endingPoint
		fprintf(fileID, '%i,', j);
	end
	fprintf(fileID, '%i};\n\n\n',startingPoint);%loop back
	splineCounter = splineCounter + 1;
	
	nextStartingPointSpline = startingPointSpline + splineCounter;
end


function [nextStartingLineLoop] = printLineLoops(startingLineLoop,startingSpline, endingSpline,fileID)
	fprintf(fileID, '// Printing line loop from spline %i to %i\n', startingSpline, endingSpline);
	fprintf(fileID,'Line Loops(%i) = {',startingLineLoop);
	for i=startingSpline:endingSpline-1
		fprintf(fileID, '%i,',i);
	end
	fprintf(fileID, '%i};\n\n\n',endingSpline);
	nextStartingLineLoop = startingLineLoop+1;
end

function printSurface(lineLoops, fileID)
	%for now there is only one surface 
	fprintf(fileID, 'Plane Surface(1) = {');
	LEN = size(lineLoops);
	LEN = LEN(2);
	
	for i=1:LEN-1
		fprintf(fileID, '%i,',lineLoops(i));
	end
	fprintf(fileID, '%i};\n',lineLoops(LEN));
end
