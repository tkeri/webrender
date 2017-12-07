/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

extern crate app_units;
extern crate euclid;
extern crate webrender;
extern crate winit;
extern crate rayon;

#[path="common/boilerplate_dx.rs"]
mod boilerplate;

use boilerplate::{Example, HandyDandyRectBuilder};
use rayon::Configuration as ThreadPoolConfig;
use rayon::ThreadPool;
use std::collections::HashMap;
use std::collections::hash_map::Entry;
use std::sync::Arc;
use std::fs::File;
use std::io::Read;
use std::sync::mpsc::{channel, Receiver, Sender};
use webrender::api::{self, DeviceUintRect, DeviceIntPoint, DisplayListBuilder, DocumentId, LayoutSize, PipelineId,
                     RenderApi, ResourceUpdates};



type ImageRenderingCommands = api::ColorU;

// Serialize/deserialze the blob.
// Ror real usecases you should probably use serde rather than doing it by hand.

fn serialize_blob(color: api::ColorU) -> Vec<u8> {
    vec![color.r, color.g, color.b, color.a]
}

fn deserialize_blob(blob: &[u8]) -> Result<ImageRenderingCommands, ()> {
    let mut iter = blob.iter();
    return match (iter.next(), iter.next(), iter.next(), iter.next()) {
        (Some(&r), Some(&g), Some(&b), Some(&a)) => Ok(api::ColorU::new(r, g, b, a)),
        (Some(&a), None, None, None) => Ok(api::ColorU::new(a, a, a, a)),
        _ => Err(()),
    };
}

// This is the function that applies the deserialized drawing commands and generates
// actual image data.
fn render_blob(
    commands: Arc<ImageRenderingCommands>,
    descriptor: &api::BlobImageDescriptor,
    tile: Option<api::TileOffset>,
) -> api::BlobImageResult {
    let color = *commands;

    // Allocate storage for the result. Right now the resource cache expects the
    // tiles to have have no stride or offset.
    let mut texels = Vec::with_capacity((descriptor.width * descriptor.height * 4) as usize);

    // Generate a per-tile pattern to see it in the demo. For a real use case it would not
    // make sense for the rendered content to depend on its tile.
    let tile_checker = match tile {
        Some(tile) => (tile.x % 2 == 0) != (tile.y % 2 == 0),
        None => true,
    };

    for y in 0 .. descriptor.height {
        for x in 0 .. descriptor.width {
            // Apply the tile's offset. This is important: all drawing commands should be
            // translated by this offset to give correct results with tiled blob images.
            let x2 = x + descriptor.offset.x as u32;
            let y2 = y + descriptor.offset.y as u32;

            // Render a simple checkerboard pattern
            let checker = if (x2 % 20 >= 10) != (y2 % 20 >= 10) {
                1
            } else {
                0
            };
            // ..nested in the per-tile cherkerboard pattern
            let tc = if tile_checker { 0 } else { (1 - checker) * 40 };

            match descriptor.format {
                api::ImageFormat::BGRA8 => {
                    texels.push(color.b * checker + tc);
                    texels.push(color.g * checker + tc);
                    texels.push(color.r * checker + tc);
                    texels.push(color.a * checker + tc);
                }
                api::ImageFormat::A8 => {
                    texels.push(color.a * checker + tc);
                }
                _ => {
                    return Err(api::BlobImageError::Other(
                        format!("Usupported image format {:?}", descriptor.format),
                    ));
                }
            }
        }
    }

    Ok(api::RasterizedBlobImage {
        data: texels,
        width: descriptor.width,
        height: descriptor.height,
    })
}

#[derive(Debug)]
enum Gesture {
    None,
    Pan,
    Zoom,
}

#[derive(Debug)]
struct Touch {
    id: u64,
    start_x: f32,
    start_y: f32,
    current_x: f32,
    current_y: f32,
}

fn dist(x0: f32, y0: f32, x1: f32, y1: f32) -> f32 {
    let dx = x0 - x1;
    let dy = y0 - y1;
    ((dx * dx) + (dy * dy)).sqrt()
}

impl Touch {
    fn distance_from_start(&self) -> f32 {
        dist(self.start_x, self.start_y, self.current_x, self.current_y)
    }

    fn initial_distance_from_other(&self, other: &Touch) -> f32 {
        dist(self.start_x, self.start_y, other.start_x, other.start_y)
    }

    fn current_distance_from_other(&self, other: &Touch) -> f32 {
        dist(self.current_x, self.current_y, other.current_x, other.current_y)
    }
}

struct TouchState {
    active_touches: HashMap<u64, Touch>,
    current_gesture: Gesture,
    start_zoom: f32,
    current_zoom: f32,
    start_pan: DeviceIntPoint,
    current_pan: DeviceIntPoint,
}

enum TouchResult {
    None,
    Pan(DeviceIntPoint),
    Zoom(f32),
}

impl TouchState {
    fn new() -> TouchState {
        TouchState {
            active_touches: HashMap::new(),
            current_gesture: Gesture::None,
            start_zoom: 1.0,
            current_zoom: 1.0,
            start_pan: DeviceIntPoint::zero(),
            current_pan: DeviceIntPoint::zero(),
        }
    }

    fn handle_event(&mut self, touch: winit::Touch) -> TouchResult {
        /*match touch.phase {
            TouchPhase::Started => {
                debug_assert!(!self.active_touches.contains_key(&touch.id));
                self.active_touches.insert(touch.id, Touch {
                    id: touch.id,
                    start_x: touch.location.0 as f32,
                    start_y: touch.location.1 as f32,
                    current_x: touch.location.0 as f32,
                    current_y: touch.location.1 as f32,
                });
                self.current_gesture = Gesture::None;
            }
            TouchPhase::Moved => {
                match self.active_touches.get_mut(&touch.id) {
                    Some(active_touch) => {
                        active_touch.current_x = touch.location.0 as f32;
                        active_touch.current_y = touch.location.1 as f32;
                    }
                    None => panic!("move touch event with unknown touch id!")
                }

                match self.current_gesture {
                    Gesture::None => {
                        let mut over_threshold_count = 0;
                        let active_touch_count = self.active_touches.len();

                        for (_, touch) in &self.active_touches {
                            if touch.distance_from_start() > 8.0 {
                                over_threshold_count += 1;
                            }
                        }

                        if active_touch_count == over_threshold_count {
                            if active_touch_count == 1 {
                                self.start_pan = self.current_pan;
                                self.current_gesture = Gesture::Pan;
                            } else if active_touch_count == 2 {
                                self.start_zoom = self.current_zoom;
                                self.current_gesture = Gesture::Zoom;
                            }
                        }
                    }
                    Gesture::Pan => {
                        let keys: Vec<u64> = self.active_touches.keys().cloned().collect();
                        debug_assert!(keys.len() == 1);
                        let active_touch = &self.active_touches[&keys[0]];
                        let x = active_touch.current_x - active_touch.start_x;
                        let y = active_touch.current_y - active_touch.start_y;
                        self.current_pan.x = self.start_pan.x + x.round() as i32;
                        self.current_pan.y = self.start_pan.y + y.round() as i32;
                        return TouchResult::Pan(self.current_pan);
                    }
                    Gesture::Zoom => {
                        let keys: Vec<u64> = self.active_touches.keys().cloned().collect();
                        debug_assert!(keys.len() == 2);
                        let touch0 = &self.active_touches[&keys[0]];
                        let touch1 = &self.active_touches[&keys[1]];
                        let initial_distance = touch0.initial_distance_from_other(touch1);
                        let current_distance = touch0.current_distance_from_other(touch1);
                        self.current_zoom = self.start_zoom * current_distance / initial_distance;
                        return TouchResult::Zoom(self.current_zoom);
                    }
                }
            }
            TouchPhase::Ended | TouchPhase::Cancelled => {
                self.active_touches.remove(&touch.id).unwrap();
                self.current_gesture = Gesture::None;
            }
        }*/

        TouchResult::None
    }
}

fn load_file(name: &str) -> Vec<u8> {
    let mut file = File::open(name).unwrap();
    let mut buffer = vec![];
    file.read_to_end(&mut buffer).unwrap();
    buffer
}

fn main() {
    let worker_config =
        ThreadPoolConfig::new().thread_name(|idx| format!("WebRender:Worker#{}", idx));

    let workers = Arc::new(ThreadPool::new(worker_config).unwrap());

    let opts = webrender::RendererOptions {
        workers: Some(Arc::clone(&workers)),
        // Register our blob renderer, so that WebRender integrates it in the resource cache..
        // Share the same pool of worker threads between WebRender and our blob renderer.
        blob_image_renderer: Some(Box::new(CheckerboardRenderer::new(Arc::clone(&workers)))),
        ..Default::default()
    };

    let mut app = App {
        touch_state: TouchState::new(),
    };

    boilerplate::main_wrapper(&mut app, Some(opts));
}

struct CheckerboardRenderer {
    // We are going to defer the rendering work to worker threads.
    // Using a pre-built Arc<ThreadPool> rather than creating our own threads
    // makes it possible to share the same thread pool as the glyph renderer (if we
    // want to).
    workers: Arc<ThreadPool>,

    // the workers will use an mpsc channel to communicate the result.
    tx: Sender<(api::BlobImageRequest, api::BlobImageResult)>,
    rx: Receiver<(api::BlobImageRequest, api::BlobImageResult)>,

    // The deserialized drawing commands.
    // In this example we store them in Arcs. This isn't necessary since in this simplified
    // case the command list is a simple 32 bits value and would be cheap to clone before sending
    // to the workers. But in a more realistic scenario the commands would typically be bigger
    // and more expensive to clone, so let's pretend it is also the case here.
    image_cmds: HashMap<api::ImageKey, Arc<ImageRenderingCommands>>,

    // The images rendered in the current frame (not kept here between frames).
    rendered_images: HashMap<api::BlobImageRequest, Option<api::BlobImageResult>>,
}

impl CheckerboardRenderer {
    fn new(workers: Arc<ThreadPool>) -> Self {
        let (tx, rx) = channel();
        CheckerboardRenderer {
            image_cmds: HashMap::new(),
            rendered_images: HashMap::new(),
            workers,
            tx,
            rx,
        }
    }
}

impl api::BlobImageRenderer for CheckerboardRenderer {
    fn add(&mut self, key: api::ImageKey, cmds: api::BlobImageData, _: Option<api::TileSize>) {
        self.image_cmds
            .insert(key, Arc::new(deserialize_blob(&cmds[..]).unwrap()));
    }

    fn update(&mut self, key: api::ImageKey, cmds: api::BlobImageData, _dirty_rect: Option<DeviceUintRect>) {
        // Here, updating is just replacing the current version of the commands with
        // the new one (no incremental updates).
        self.image_cmds
            .insert(key, Arc::new(deserialize_blob(&cmds[..]).unwrap()));
    }

    fn delete(&mut self, key: api::ImageKey) {
        self.image_cmds.remove(&key);
    }

    fn request(
        &mut self,
        _resources: &api::BlobImageResources,
        request: api::BlobImageRequest,
        descriptor: &api::BlobImageDescriptor,
        _dirty_rect: Option<api::DeviceUintRect>,
    ) {
        // This method is where we kick off our rendering jobs.
        // It should avoid doing work on the calling thread as much as possible.
        // In this example we will use the thread pool to render individual tiles.

        // Gather the input data to send to a worker thread.
        let cmds = Arc::clone(&self.image_cmds.get(&request.key).unwrap());
        let tx = self.tx.clone();
        let descriptor = descriptor.clone();

        self.workers.spawn(move || {
            let result = render_blob(cmds, &descriptor, request.tile);
            tx.send((request, result)).unwrap();
        });

        // Add None in the map of rendered images. This makes it possible to differentiate
        // between commands that aren't finished yet (entry in the map is equal to None) and
        // keys that have never been requested (entry not in the map), which would cause deadlocks
        // if we were to block upon receing their result in resolve!
        self.rendered_images.insert(request, None);
    }

    fn resolve(&mut self, request: api::BlobImageRequest) -> api::BlobImageResult {
        // In this method we wait until the work is complete on the worker threads and
        // gather the results.

        // First look at whether we have already received the rendered image
        // that we are looking for.
        match self.rendered_images.entry(request) {
            Entry::Vacant(_) => {
                return Err(api::BlobImageError::InvalidKey);
            }
            Entry::Occupied(entry) => {
                // None means we haven't yet received the result.
                if entry.get().is_some() {
                    let result = entry.remove();
                    return result.unwrap();
                }
            }
        }

        // We haven't received it yet, pull from the channel until we receive it.
        while let Ok((req, result)) = self.rx.recv() {
            if req == request {
                // There it is!
                return result;
            }
            self.rendered_images.insert(req, Some(result));
        }

        // If we break out of the loop above it means the channel closed unexpectedly.
        Err(api::BlobImageError::Other("Channel closed".into()))
    }
    fn delete_font(&mut self, _font: api::FontKey) {}
    fn delete_font_instance(&mut self, _instance: api::FontInstanceKey) {}
}

struct App {
    touch_state: TouchState,
}

impl Example for App {
    fn render(&mut self,
              api: &RenderApi,
              builder: &mut DisplayListBuilder,
              resources: &mut ResourceUpdates,
              layout_size: LayoutSize,
              _pipeline_id: PipelineId,
              _document_id: DocumentId) {
        let blob_img1 = api.generate_image_key();
        resources.add_image(
            blob_img1,
            api::ImageDescriptor::new(500, 500, api::ImageFormat::BGRA8, true),
            api::ImageData::new_blob_image(serialize_blob(api::ColorU::new(50, 50, 150, 255))),
            Some(128),
        );

        let blob_img2 = api.generate_image_key();
        resources.add_image(
            blob_img2,
            api::ImageDescriptor::new(200, 200, api::ImageFormat::BGRA8, true),
            api::ImageData::new_blob_image(serialize_blob(api::ColorU::new(50, 150, 50, 255))),
            None,
        );

        let bounds = api::LayoutRect::new(api::LayoutPoint::zero(), layout_size);
        let info = api::LayoutPrimitiveInfo::new(bounds);
        builder.push_stacking_context(
            &info,
            api::ScrollPolicy::Scrollable,
            None,
            api::TransformStyle::Flat,
            None,
            api::MixBlendMode::Normal,
            Vec::new(),
        );

        let info = api::LayoutPrimitiveInfo::new((30, 30).by(500, 500));
        builder.push_image(
            &info,
            api::LayoutSize::new(500.0, 500.0),
            api::LayoutSize::new(0.0, 0.0),
            api::ImageRendering::Auto,
            blob_img1,
        );

        let info = api::LayoutPrimitiveInfo::new((600, 600).by(200, 200));
        builder.push_image(
            &info,
            api::LayoutSize::new(200.0, 200.0),
            api::LayoutSize::new(0.0, 0.0),
            api::ImageRendering::Auto,
            blob_img2,
        );

        builder.pop_stacking_context();
    }

    fn on_event(&mut self,
                event: winit::Event,
                api: &RenderApi,
                document_id: DocumentId) -> bool {
        /*match event {
            winit::Event::Touch(touch) => {
                match self.touch_state.handle_event(touch) {
                    TouchResult::Pan(pan) => {
                        api.set_pan(document_id, pan);
                        api.generate_frame(document_id, None);
                    }
                    TouchResult::Zoom(zoom) => {
                        api.set_pinch_zoom(document_id, ZoomFactor::new(zoom));
                        api.generate_frame(document_id, None);
                    }
                    TouchResult::None => {}
                }
            }
            _ => ()
        }*/

        false
    }
}
