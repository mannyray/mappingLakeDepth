
%Plotting visual of lake:

%go through all possible x and y points in grid version of map

curveCount = 1;

%first entry is lake, followed by islands
lonFileName = {'mainLakeLon.txt', 'island1Lon.txt'};
latFileName = {'mainLakeLat.txt', 'island1Lat.txt'};

%msh file
meshFile = 'noislandpointsFiltered.txt';
%depth 
categories = 5;
depth = [0, 0.5, 1, 1.5, 2];
distanceAtDepth = [0,200, 400, 500, 600];
%gridSize
fileRefCord = fopen('referenceCoord.txt');

%read in reference coords
referCoord = textscan(fileRefCord,'%f');
lat0 = referCoord{1}(1);
lon0 = referCoord{1}(2);
h0 = 0;




curveX = {};
curveY = {};
for i=1:curveCount
	latOutline = readInData(latFileName{i});
	lonOutline = readInData(lonFileName{i});
	[X,Y] = lonlat_to_xy(latOutline,lonOutline,0.*lonOutline,lat0,lon0,h0);
	curveX{i} = X;
	curveY{i} = Y;
end


%read in MSH file
nodesCoords = readInMeshData(meshFile);

%go through all of the nodes and check their depth:

[xy,distance,t_a] = distance2curve([curveX{1}, curveY{1}],nodesCoords);

coordCount = size(nodesCoords);
coordCount = coordCount(1);
depthdata.x = [];
depthdata.y = [];
depthdata.H = [];
for i=1:coordCount
	
	curDepth = 0;
	for j=1:categories
		if distance(i) >= distanceAtDepth(j)
			curDepth = depth(j);
		end
	end	
	depthdata.x = [depthdata.x, nodesCoords(i,1)];
	depthdata.y = [depthdata.y, nodesCoords(i,2)];
	depthdata.H = [depthdata.H, curDepth];
end



%returns N X 1 vector:
function [coords] = readInData(fileName)
	fileID = fopen(fileName);
	coords = textscan(fileID,'%f');
	coords = (coords{1});
end


function [nodesCoords] = readInMeshData(filename)
	fileID = fopen(filename);
	C = textscan(fileID,'%f %f');
	nodesCoords = [C{1}, C{2}];
end

%return X and Y coordinates of lon-lat points that represent a lake
function [X,Y] = lonlat_to_xy(latVec,lonVec,hVec,lat0,lon0,h0)
	[X,Y,Z] = geodetic2ned(latVec,lonVec,hVec, lat0, lon0, h0, wgs84Ellipsoid);
end

%function that given a series of points outlining a lake, will return the
%min and max x y coordinates of said lake
%X and Y are in coortesian coordinates
function [minx,miny,maxx,maxy] = minXYmaxXY(X,Y)
	minx = min(X);
	miny = min(Y);
	maxx = max(X);
	maxy = max(Y);
end
