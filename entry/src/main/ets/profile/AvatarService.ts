import { fileIo, picker } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { BackgroundImageSource } from '../settings/PageBackgroundService';

const AVATAR_SIZE = 320;
const DIRECTORY_NAME = 'profile';

/** Opens the picker for one source and returns the chosen uri, or an empty string when cancelled. */
export async function pickAvatarUri(source: BackgroundImageSource, context: common.Context): Promise<string> {
  if (source === BackgroundImageSource.CAMERA) {
    const result = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK,
      saveUri: ''
    });
    return result.resultCode === 0 ? result.resultUri : '';
  }
  if (source === BackgroundImageSource.FILES) {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.fileSuffixFilters = ['图片|.png,.jpg,.jpeg,.webp,.bmp,.heic,.heif'];
    const uris = await new picker.DocumentViewPicker(context).select(options);
    return uris.length > 0 ? uris[0] : '';
  }
  const options = new photoAccessHelper.PhotoSelectOptions();
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
  options.maxSelectNumber = 1;
  const result = await new photoAccessHelper.PhotoViewPicker().select(options);
  return result.photoUris.length > 0 ? result.photoUris[0] : '';
}

/** Crops the picture to a square, scales it to 320 px and stores it in the sandbox. */
export async function saveAvatar(uri: string, context: common.Context, previousPath: string): Promise<string> {
  const directory = `${context.filesDir}/${DIRECTORY_NAME}`;
  if (!fileIo.accessSync(directory)) {
    fileIo.mkdirSync(directory, true);
  }
  const destination = `${directory}/avatar-${Date.now()}.png`;
  const sourceFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  const sourceImage = image.createImageSource(sourceFile.fd);
  try {
    const info = await sourceImage.getImageInfo();
    const side = Math.min(info.size.width, info.size.height);
    const pixelMap = await sourceImage.createPixelMap({
      desiredRegion: {
        x: Math.floor((info.size.width - side) / 2),
        y: Math.floor((info.size.height - side) / 2),
        size: { width: side, height: side }
      },
      desiredSize: { width: AVATAR_SIZE, height: AVATAR_SIZE }
    });
    try {
      const packer = image.createImagePacker();
      const buffer = await packer.packToData(pixelMap, { format: 'image/png', quality: 100 });
      writeBuffer(destination, buffer);
    } finally {
      pixelMap.release();
    }
  } finally {
    sourceImage.release();
    fileIo.closeSync(sourceFile);
  }
  if (previousPath.length > 0 && previousPath !== destination && fileIo.accessSync(previousPath)) {
    fileIo.unlinkSync(previousPath);
  }
  return destination;
}

/** Removes a stored avatar; a missing file is treated as already gone. */
export function removeAvatar(path: string): void {
  if (path.length > 0 && fileIo.accessSync(path)) {
    fileIo.unlinkSync(path);
  }
}

function writeBuffer(path: string, buffer: ArrayBuffer): void {
  const file = fileIo.openSync(path,
    fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
  try {
    fileIo.writeSync(file.fd, buffer);
  } finally {
    fileIo.closeSync(file);
  }
}
