 --[[
    Copyright (c) 2015-present, Facebook, Inc.
    All rights reserved.

    This source code is licensed under the BSD-style license found in the
    LICENSE file in the root directory of this source tree. An additional grant
    of patent rights can be found in the PATENTS file in the same directory.
]]--

require 'image'
paths.dofile('dataset2.lua')

-- This file contains the data-loading logic and details.
-- It is run by each data-loader thread.
------------------------------------------
-------- COMMON CACHES and PATHS
-- Check for existence of opt.data
opt.data = os.getenv('DATA_ROOT') or '/media/harryyang/New Volume/vision-harry/mp4_videos/train_folder_small'
if not paths.dirp(opt.data) then
    error('Did not find directory: ', opt.data)
end

-- a cache file of the training metadata (if doesnt exist, will be created)
local cache = "cache_small"
local cache_prefix = opt.data:gsub('/', '_')
os.execute('mkdir -p cache_small')
local trainCache = paths.concat(cache, cache_prefix .. '_trainCache.t7')

--------------------------------------------------------------------------------------------
local loadSize   = {1, opt.loadSize}
local sampleSize = {1, opt.loadSize}

local function loadImage(path)
   local input = image.load(path, 3, 'float')
   -- find the smaller dimension, and resize it to loadSize[2] (while keeping aspect ratio)
   local iW = input:size(3)
   local iH = input:size(2)
  

   if iW < iH then
      input = image.scale(input, loadSize[2], loadSize[2] * iH / iW)
   else
      input = image.scale(input, loadSize[2] * iW / iH, loadSize[2])
   end

   return input
end

-- channel-wise mean and std. Calculate or load them from disk later in the script.
local mean,std
--------------------------------------------------------------------------------
-- Hooks that are used for each image that is loaded

-- function to load the image, jitter it appropriately (random crops etc.)
local trainHook = function(self, path)
   collectgarbage()
   local input = loadImage(path)
   local input_y=image.rgb2y(input)
   
   input=image.scale(input,opt.loadSize/opt.scale,opt.loadSize/opt.scale,'bicubic')
   input=image.scale(input,opt.loadSize,opt.loadSize,'bicubic')
   local input_y2=image.rgb2y(input)
  
   return input_y,input_y2
end

--------------------------------------
-- trainLoader
if paths.filep(trainCache) then
   print('Loading train metadata from cache')
   trainLoader = torch.load(trainCache)
   trainLoader.sampleHookTrain = trainHook
   trainLoader.loadSize = {1, opt.loadSize, opt.loadSize}
   trainLoader.sampleSize = {1, sampleSize[2], sampleSize[2]}
else
   print('Creating train metadata')
   trainLoader = dataLoader{
      paths = {opt.data},
      loadSize = {1, loadSize[2], loadSize[2]},
      sampleSize = {1, sampleSize[2], sampleSize[2]},
      split = 100,
      verbose = true
   }
   torch.save(trainCache, trainLoader)
   print('saved metadata cache at', trainCache)
   trainLoader.sampleHookTrain = trainHook
end
collectgarbage()

-- do some sanity checks on trainLoader
do
   local class = trainLoader.imageClass
   local nClasses = #trainLoader.classes
   assert(class:max() <= nClasses, "class logic has error")
   assert(class:min() >= 1, "class logic has error")
end
