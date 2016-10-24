% inrvideowrite class creatres a movie file with INRimage format
% 
% To create the movie firstly the class constructor must be called.
% Then we call the add_frame method one time per each frame we want to
% insert in the movie
% Finally we call the destructor of the class to update and close the file
% Example to create a 3-frame 320x240 movie:
%  vid = inrvideowrite('movie.inr')
%  vid.add_frame(uint8(255*ones(240,320)))
%  vid.add_frame(uint8(zeros(240,320)))
%  vid.add_frame(uint8(255*ones(240,320)))
%  vid.delete()
% The input matrix of add_frame must have the same size and data type for all the calls.
%
%   See also INRWRITE, AVI2INR.

%   Copyright (C) 2016 by Richard R. Carrillo 
%   $Revision: 1.0 $  $Date: 26/9/2016 $

%   This program is free software; you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation; either version 3 of the License, or
%   (at your option) any later version.
classdef inrvideowrite<handle
   properties
      ydim,xdim,zdim
      inr_type
      inr_type_len
      fh
      inr_header_len=256;
      inr_header_start_temp=[...
         '#INRIMAGE-4#{\n' ...
         'XDIM=%d\n' ...
         'YDIM=%d\n' ...
         'ZDIM=%d\n' ...
         'VDIM=1\n' ...
         'VX=1\n' ...
         'VY=1\n' ...
         'VZ=1\n' ...
         'TYPE=%s\n' ...
         'PIXSIZE=%d bits\n' ...
         'SCALE=2**0\n' ...
         'CPU=pc\n'];
      inr_header_end=sprintf('\n##}\n');
      inr_type_list={'float', 'signed fixed', 'unsigned fixed'};
      data_class
      data_size
   end
   methods
      function obj = inrvideowrite(filename)
         obj.inr_type_len = 0; % When this proprty is set to 0, it indicates that the other properties are not set yet.
         obj.fh=fopen(filename,'w');
         if nargin ~= -1
             fprintf(obj.fh,repmat(' ',1,obj.inr_header_len));
         else
            error(['Creating file ' filename])
         end
      end
      function add_frame(obj, frame)
         if obj.inr_type_len == 0 % Image porperties are not stablished yet: Set image object properties
            obj.data_class=class(frame);
            obj.data_size=size(frame);
            switch(obj.data_class)
               case {'single', 'double'}
                  obj.inr_type=obj.inr_type_list{1};
               case {'int8', 'int16', 'int32', 'int64'}
                  obj.inr_type=obj.inr_type_list{2};
               case {'uint8', 'uint16', 'uint32', 'uint64'}
                  obj.inr_type=obj.inr_type_list{3};
            end

            switch(obj.data_class)
               case {'int8', 'uint8'}
                  obj.inr_type_len=8;
               case {'int16', 'uint16'}
                  obj.inr_type_len=16;
               case {'int32', 'uint32', 'single'}
                  obj.inr_type_len=32;
               case {'int64', 'uint64', 'double'}
                  obj.inr_type_len=64;
            end
            [obj.ydim,obj.xdim]=size(frame);
            obj.zdim=0; % No frames in the video so far
         end
            if isequal(obj.data_class,class(frame)) && isequal(obj.data_size,size(frame)) % check if the specied frame properties match
               fwrite(obj.fh,permute(frame,[2 1 3]),obj.data_class);
               obj.zdim=obj.zdim+1;
            else
               error('properties of specified frame does not match those of previous ones');
            end
      end
      function delete(obj)
         fseek(obj.fh,0,'bof');
         inr_header_start=sprintf(obj.inr_header_start_temp, obj.xdim, obj.ydim, obj.zdim, obj.inr_type, obj.inr_type_len);
         fprintf(obj.fh,inr_header_start);
         fprintf(obj.fh,repmat('\n',1,obj.inr_header_len-length(inr_header_start)-length(obj.inr_header_end)));
         fprintf(obj.fh,obj.inr_header_end);
         fclose(obj.fh);
      end
   end
end