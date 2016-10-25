%INRLOAD loads an INR file
%   This function allows the user to partially read a INR file in a matrix
%   which is returned by the function.
%   INRLOAD filename load the whole INR filename file.
%   If additional arguments are specified, a specific part of the file is
%   loaded:
%   INRLOAD filename x_ini x_end only reads a column from all source images
%   (from column x_ini to column x_end). First column is zero.
%   INRLOAD filename x_ini x_end y_ini y_end only reads a square from 
%   all source images (from column x_ini to column x_end and from row x_ini
%   to row x_end).
%   INRLOAD filename x_ini x_end y_ini y_end z_ini z_end only reads a
%   square from a specific interval of source images (from image z_ini to
%   image z_end).
%   INRLOAD filename x_ini x_end y_ini y_end z_ini z_end v_ini v_end
%   only reads a square from a specific interval of source images of a
%   specific interval of pixel dimensions (from dim. v_ini to dim. v_end).
%   (in case a pixel is defined by a vector).
%
%   See also INRWRITE.

%   Copyright (C) 2016 by Richard R. Carrillo 
%   $Revision: 1.0 $  $Date: 25/10/2016 $

%   This program is free software; you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation; either version 3 of the License, or
%   (at your option) any later version.
function voxels=inrload(varargin)

nargs=nargin;

if nargs ~= 1 && nargs ~= 3 && nargs ~= 5 && nargs ~= 7 && nargs ~= 9
      disp('You must specify 1, 3, 5, 7 or 9 arguments');
      disp('inrload filename [x_ini x_end [y_ini y_end [z_ini z_end [v_ini v_end]]]]');
      disp('All arguments must numeric except the first one')
      disp('type: help inrload for more help');
else
    filename = varargin{1};

    fid = fopen(filename,'rb');
    if fid ~= -1
        
        header=inr_read_header(fid);
        if isempty(header.read_error) % Header successfully read
            disp(['Dimensions of data in file: ' num2str(header.n_dims)])
            if nargs == 1 % the whole file must be loaded
                disp(['loading file: ' filename ' completely']);
                voxels=fread(fid, Inf, header.matlab_data_type); % Read the whole file at once to speed up the loading process
                disp(' 100%');
                if numel(voxels)==prod(header.n_dims)
                    voxels=reshape(voxels, header.n_dims);
                    voxels=permute(voxels,[2 1 3 4]);
                else
                    disp('Error: Number of voxel values in file does not correspond with dimension sizes in header')
                end
            else % only a part of the file must be loaded
                Dim_names='XYZV';
                N_dims=length(Dim_names);
                
                % If fn argument dimension data types are strings, convert to doubles
                % The type may change denpending on how the fn is executed
                for arg_ind=2:nargs
                    if isa(varargin{arg_ind},'char')
                        vargs_num(arg_ind-1) = str2double(varargin{arg_ind});
                    else
                        vargs_num(arg_ind-1) = varargin{arg_ind};
                    end
                end
                
                dim_size=[zeros(N_dims,1) ones(N_dims,1)*Inf]; % Default dimension coordinates of data to load: load all data: 0 -> Inf
                % Replace dim_size values with the dimension limits specified by user
                for arg_ind=1:(nargs-1)/2 % Parse input dimension coordenate intervals
                    dim_size(arg_ind,:) = [vargs_num(arg_ind*2 - 1) vargs_num(arg_ind*2)];
                end

                
                dim_max_auto=isinf(dim_size(:,2)); % Dimensions in which the user want to load all the elements
                dim_size(dim_max_auto,2)=header.n_dims(dim_max_auto)-1;
                
                disp(['Partially loading activity file ' filename ':']);
                for dim_ind=1:N_dims
                    disp([' dim. ' Dim_names(dim_ind) ': from ' num2str(dim_size(dim_ind,1)) ' to ' num2str(dim_size(dim_ind,2))])
                end
                % Check that input argument values are compatible with
                % dimensions of data in the specified file
                if all(dim_size >= 0)
                    if all(dim_size(:,1) < header.n_dims') && all(dim_size(:,2) < header.n_dims')
                        % Load data from file
                        % Move file pointer to the first data in V dim. to load
                        fseek(fid, dim_size(4,1) * (header.data_size/8) * prod(header.n_dims(1:3)), 'cof');
                        for n_v_dim=1:(1+dim_size(4,2)-dim_size(4,1))
                            % Move file pointer to the first required data in Z dim.
                            fseek(fid, dim_size(3,1) * (header.data_size/8) * prod(header.n_dims(1:2)), 'cof');
                            for n_z_dim=1:(1+dim_size(3,2)-dim_size(3,1))
                                % For the remaining dimensions (X and Y) we load all the elements
                                % since it is probably faster than moving the file pointer many times
                                xy_voxels=fread(fid, prod(header.n_dims(1:2)), header.matlab_data_type); % Read a whole image each time
                                xy_voxels=reshape(xy_voxels, header.n_dims(1:2));
                                xy_voxels=permute(xy_voxels,[2 1]);
                                voxels(:,:,n_z_dim,n_v_dim)=xy_voxels(1+(dim_size(2,1):dim_size(2,2)), 1+(dim_size(1,1):dim_size(1,2)));
                            end
                        end
                        
                    else
                        disp('Error: all specified dimension limits must be lower than the dimensions in the specified file')
                    end
                    
                else
                    disp('Error: all specified dimension limits must be positive or zero')
                end
                
            end
            if header.change_endianness
                voxels=swapbytes(voxels); % File endianness and computer endianness are different, so data bytes must be swapped
            end
        else
            disp(['Error reading file header: ' header.read_error])
        end
        fclose(fid);
    else
        disp(['Cannot output spike file: ' varargin{2}]);        
    end    
end

% Load INR file header and returns a struct containing the header fields
function header=inr_read_header(fid)
INR_header_ID='#INRIMAGE-4#';
INR_header_end='##}';

header=struct('read_error',''); % field read_ok will specify the obtained error or '' if the file header was successfully read
if fid ~= -1 % Valid file identifier
    header_id=fscanf(fid,'%[^{]', 1); % Read format ID string
    if strncmp(INR_header_ID,header_id,length(header_id)) == 1
        fscanf(fid,' { \n', 1); % Skip block start and new line
        end_header=false;
        while ~end_header
            header_line = fgetl(fid);
            if ischar(header_line) % If a valid file line has been read:
                if strcmp(INR_header_end, header_line) == 0 % If it is not the header end:
                    [param_name,param_name_read]=sscanf(header_line,'%[^=]=',1);
                    if param_name_read==1
                        param_value=sscanf(header_line,'%*[^=]=%[^\n]',1); % Skip param name and '=' and get param value
                        switch param_name
                            case 'XDIM' % Length in X dimension
                                header.n_dims(1)=str2num(param_value);
                            case 'YDIM'
                                header.n_dims(2)=str2num(param_value);
                            case 'ZDIM'
                                header.n_dims(3)=str2num(param_value);
                            case 'VDIM'
                                header.n_dims(4)=str2num(param_value);
                            case 'VX'
                                header.voxel_size(1)=str2num(param_value);
                            case 'VY'
                                header.voxel_size(2)=str2num(param_value);
                            case 'VZ'
                                header.voxel_size(3)=str2num(param_value);
                            case 'TYPE'
                                header.data_type=param_value;
                            case 'PIXSIZE'
                                header.data_size=sscanf(param_value,' %u',1);
                            case 'SCALE'
                                header.scale=param_value;
                            case 'CPU'
                                header.cpu=param_value;
                            otherwise
                                warning(['Unexpected header parameter: ' param_name '-' param_value])
                        end
                    end
                else
                    end_header=true; % header end found: exit loop
                end
            else
                end_header=true; % file end found: exit
            end
        end
    else
        header.read_error='The format of specified file is unknown';
    end
    if isempty(header.read_error) % Header successfully read
        % Translate INR data type name into Matlab data type name
        if isfield(header, 'data_type') && isfield(header, 'data_size')
            data_type_inr=[header.data_type '_' num2str(header.data_size)]; % Compose a data type name just to be used in switch statement
            switch lower(data_type_inr)
                case 'unsigned fixed_8'
                    header.matlab_data_type='uint8';
                case 'signed fixed_8'
                    header.matlab_data_type='int8';
                case 'unsigned fixed_16'
                    header.matlab_data_type='uint16';
                case 'signed fixed_16'
                    header.matlab_data_type='int16';
                case 'unsigned fixed_32'
                    header.matlab_data_type='uint32';
                case 'signed fixed_32'
                    header.matlab_data_type='int32';
                case 'unsigned fixed_64'
                    header.matlab_data_type='uint64';
                case 'signed fixed_64'
                    header.matlab_data_type='int64';
                case {'float_32','double_32'}
                    header.matlab_data_type='single';
                case {'float_64','double_64'}
                    header.matlab_data_type='double';
                otherwise
                    header.read_error='Incompatible data type specified in file header';
            end
            if isempty(header.read_error) % Data type successfully obtained
                if isfield(header, 'cpu') % Endianness specified in header
                    [~,~,local_endianness]=computer;
                    switch header.cpu
                        case {'decm','alpha','pc'}
                            header.endianness='L';
                        case {'sun','sgi'}
                            header.endianness='B';
                        otherwise
                            header.read_error='Unknown CPU type specified in header';
                    end
                    if isfield(header, 'endianness')
                        header.change_endianness=(header.endianness~=local_endianness);
                    end
                end
            end
        end
    end
else
    header.read_error='Invalid file identifier';
end
