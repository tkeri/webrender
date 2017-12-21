/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

//use super::shader_source;
use api::ImageFormat;
use euclid::Transform3D;
use internal_types::RenderTargetMode;
use std::collections::{HashSet, HashMap};
use std::fs::File;
use std::io::Read;
use std::iter::repeat;
use std::mem;
use std::ops::Add;
use std::path::PathBuf;
use std::ptr;
use std::rc::Rc;
use std::thread;
use api::{DeviceIntPoint, DeviceIntRect, DeviceIntSize, DeviceUintRect, DeviceUintSize};

use rand::Rng;
use std;
use gfx;
use gfx::{buffer, command, device as d, image as i, memory as m, pass, pso, pool};
use gfx::{Device as BackendDevice, Instance, QueueFamily, Surface, Swapchain};
use gfx::{
    DescriptorPool, Gpu, FrameSync, Primitive,
    Backbuffer, SwapchainConfig,
};
use gfx::format::{ChannelType, Formatted, Srgba8 as ColorFormat, Swizzle, Vec2, Vec3, Vec4};
use gfx::pass::Subpass;
use gfx::pso::{PipelineStage, ShaderStageFlags};
use gfx::queue::Submission;
use winit;
use back;

const COLOR_RANGE: i::SubresourceRange = i::SubresourceRange {
    aspects: i::AspectFlags::COLOR,
    levels: 0 .. 1,
    layers: 0 .. 1,
};

const ENTRY_NAME: &str = "main";

#[derive(Debug, Clone, Copy)]
#[allow(non_snake_case)]
struct Vertex {
    aPosition: [f32; 3],
}

#[derive(Debug, Clone, Copy)]
#[allow(non_snake_case)]
struct Locals {
    uTransform: [[f32; 4]; 4],
    uDevicePixelRatio: f32,
    uMode: i32,
}

#[derive(Debug, Clone, Copy)]
#[allow(non_snake_case)]
struct PrimitiveInstance {
    aDataA: [i32; 4],
    aDataB: [i32; 4],
}

/*const QUAD: [Vertex; 6] = [
    Vertex { pos: [ -0.5, 0.5 ], color_in: [0.0, 1.0, 0.0, 1.0] },
    Vertex { pos: [  0.5, 0.5 ], color_in: [1.0, 1.0, 0.0, 1.0] },
    Vertex { pos: [  0.5,-0.5 ], color_in: [1.0, 0.0, 0.0, 1.0] },

    Vertex { pos: [ -0.5, 0.5 ], color_in: [0.0, 1.0, 0.0, 1.0] },
    Vertex { pos: [  0.5,-0.5 ], color_in: [1.0, 0.0, 0.0, 1.0] },
    Vertex { pos: [ -0.5,-0.5 ], color_in: [0.0, 1.0, 0.0, 1.0] },
];*/

const QUAD: [Vertex; 6] = [
    Vertex { aPosition: [  0.0, 0.0, 0.0  ] },
    Vertex { aPosition: [  1.0, 0.0, 0.0  ] },
    Vertex { aPosition: [  0.0,-1.0, 0.0  ] },
    
    Vertex { aPosition: [  0.0,-1.0, 0.0  ] },
    Vertex { aPosition: [  1.0, 0.0, 0.0  ] },
    Vertex { aPosition: [  1.0,-1.0, 0.0  ] },
];

/*use gfx;
use gfx::CombinedError;
use gfx::Factory;
use gfx::texture::Kind;
use gfx::traits::FactoryExt;
use gfx::format::{DepthStencil as DepthFormat, Rgba8 as ColorFormat};
use gfx::format::{Formatted, R8, Rgba8, Rgba32F, Srgba8, SurfaceTyped, TextureChannel, TextureSurface, Unorm};
use gfx::format::{R8_G8_B8_A8, R32_G32_B32_A32};
use gfx::handle::Sampler;
use gfx::memory::Typed;
use pipelines::{Position};*/
use tiling::RenderTargetKind;
use renderer::{BlendMode, MAX_VERTEX_TEXTURE_WIDTH, TextureSampler};

//use back;

pub const LAYER_TEXTURE_WIDTH: usize = 1017;
pub const RENDER_TASK_TEXTURE_WIDTH: usize = 1023;
pub const TEXTURE_HEIGTH: usize = 8;
pub const DEVICE_PIXEL_RATIO: f32 = 1.0;
// We need this huge number for the large examples
//pub const MAX_INSTANCE_COUNT: usize = 12000;
pub const MAX_INSTANCE_COUNT: usize = 1024;

pub const A_STRIDE: usize = 1;
pub const RG_STRIDE: usize = 2;
pub const RGB_STRIDE: usize = 3;
pub const RGBA_STRIDE: usize = 4;

pub type TextureId = u32;

//pub const INVALID: TextureId = 0;
pub const DUMMY_ID: TextureId = 0;
//pub const DUMMY_RGBA8: TextureId = 1;
const FIRST_UNRESERVED_ID: TextureId = DUMMY_ID + 1;

//pub type A8 = (R8, Unorm);

#[derive(Debug, Copy, Clone, PartialEq, Ord, Eq, PartialOrd)]
pub struct FrameId(usize);

impl FrameId {
    pub fn new(value: usize) -> FrameId {
        FrameId(value)
    }
}

impl Add<usize> for FrameId {
    type Output = FrameId;

    fn add(self, other: usize) -> FrameId {
        FrameId(self.0 + other)
    }
}

pub struct TextureSlot(pub usize);

// In some places we need to temporarily bind a texture to any slot.
const DEFAULT_TEXTURE: TextureSlot = TextureSlot(0);

#[derive(Copy, Clone, Debug, PartialEq)]
pub enum TextureTarget {
    Default,
    Array,
    Rect,
    External,
}

#[derive(Copy, Clone, Debug, PartialEq)]
pub enum TextureStorage {
    CacheA8,
    CacheRGBA8,
    Image,
    //TODO External
}

#[derive(Copy, Clone, Debug, PartialEq)]
pub enum TextureFilter {
    Nearest,
    Linear,
}


/*pub struct DataTexture<T> where T: gfx::format::TextureFormat {
    pub handle: gfx::handle::Texture<R, T::Surface>,
    pub srv: gfx::handle::ShaderResourceView<R, T::View>,
}

impl<T> DataTexture<T> where T: gfx::format::TextureFormat {
    pub fn create<F>(factory: &mut F, size: [usize; 2], data: Option<(&[&[u8]], gfx::texture::Mipmap)>) -> Result<DataTexture<T>, CombinedError>
        where F: gfx::Factory<R>
    {
        let (width, height) = (size[0] as u16, size[1] as u16);
        let tex_kind = Kind::D2(width, height, gfx::texture::AaMode::Single);

        let (surface, view) = {
            let surface = <T::Surface as gfx::format::SurfaceTyped>::get_surface_type();
            let desc = gfx::texture::Info {
                kind: tex_kind,
                levels: 1,
                format: surface,
                bind: gfx::memory::SHADER_RESOURCE,
                usage: gfx::memory::Usage::Dynamic,
            };
            let cty = <T::Channel as gfx::format::ChannelTyped>::get_channel_type();
            let raw = try!(factory.create_texture_raw(desc, Some(cty), data));
            let levels = (0, raw.get_info().levels - 1);
            let tex = Typed::new(raw);
            let view = try!(factory.view_texture_as_shader_resource::<T>(&tex, levels, gfx::format::Swizzle::new()));
            (tex, view)
        };

        Ok(DataTexture {
            handle: surface,
            srv: view,
        })
    }

    #[inline(always)]
    pub fn get_size(&self) -> (usize, usize) {
        let (w, h, _, _) = self.handle.get_info().kind.get_dimensions();
        (w as usize, h as usize)
    }
}

pub struct CacheTexture<T> where T: gfx::format::RenderFormat + gfx::format::TextureFormat {
    //pub id: TextureId,
    pub handle: gfx::handle::Texture<R, T::Surface>,
    pub rtv: gfx::handle::RenderTargetView<R, T>,
    pub srv: gfx::handle::ShaderResourceView<R, T::View>,
    pub dsv: gfx::handle::DepthStencilView<R, DepthFormat>,
}

impl<T> CacheTexture<T> where T: gfx::format::RenderFormat + gfx::format::TextureFormat {
    pub fn create<F>(factory: &mut F, size: [usize; 2]) -> Result<CacheTexture<T>, CombinedError>
        where F: gfx::Factory<R>
    {
        let (width, height) = (size[0] as u16, size[1] as u16);
        let tex_kind = Kind::D2Array(width, height, 1, gfx::texture::AaMode::Single);

        let (surface, rtv, view, dsv) = {
            let surface = <T::Surface as gfx::format::SurfaceTyped>::get_surface_type();
            let desc = gfx::texture::Info {
                kind: tex_kind,
                levels: 1,
                format: surface,
                bind: gfx::memory::SHADER_RESOURCE | gfx::memory::RENDER_TARGET | gfx::TRANSFER_SRC | gfx::TRANSFER_DST,
                usage: gfx::memory::Usage::Data,
            };
            let cty = <T::Channel as gfx::format::ChannelTyped>::get_channel_type();
            let raw = try!(factory.create_texture_raw(desc, Some(cty), None));
            let levels = (0, raw.get_info().levels - 1);
            let tex = Typed::new(raw);
            let rtv = try!(factory.view_texture_as_render_target(&tex, 0, None));
            let view = try!(factory.view_texture_as_shader_resource::<T>(&tex, levels, gfx::format::Swizzle::new()));
            let tex_dsv = try!(factory.create_texture(tex_kind, 1, gfx::memory::SHADER_RESOURCE | gfx::memory::DEPTH_STENCIL, gfx::memory::Usage::Data, Some(gfx::format::ChannelType::Unorm)));
            let dsv = try!(factory.view_texture_as_depth_stencil_trivial(&tex_dsv));
            (tex, rtv, view, dsv)
        };

        Ok(CacheTexture {
            handle: surface,
            rtv: rtv,
            srv: view,
            dsv: dsv,
        })
    }

    #[inline(always)]
    pub fn get_size(&self) -> (usize, usize) {
        let (w, h, _, _) = self.handle.get_info().kind.get_dimensions();
        (w as usize, h as usize)
    }
}

pub struct ImageTexture<T> where T: gfx::format::TextureFormat {
    //pub id: TextureId,
    pub handle: gfx::handle::Texture<R, T::Surface>,
    pub srv: gfx::handle::ShaderResourceView<R, T::View>,
    pub filter: TextureFilter,
    pub format: ImageFormat,
    // Only used on dx11
    pub data: Vec<u8>,
}

impl<T> ImageTexture<T> where T: gfx::format::TextureFormat {
    pub fn create<F>(factory: &mut F, size: [usize; 2], layer_count: u16, filter: TextureFilter, format: ImageFormat) -> Result<ImageTexture<T>, CombinedError>
        where F: gfx::Factory<R>
    {
        let (width, height) = (size[0] as u16, size[1] as u16);
        let tex_kind = Kind::D2Array(width, height, layer_count, gfx::texture::AaMode::Single);

        let (surface, view) = {
            let surface = <T::Surface as gfx::format::SurfaceTyped>::get_surface_type();
            let desc = gfx::texture::Info {
                kind: tex_kind,
                levels: 1,
                format: surface,
                bind: gfx::memory::SHADER_RESOURCE,
                usage: gfx::memory::Usage::Dynamic,
            };
            let cty = <T::Channel as gfx::format::ChannelTyped>::get_channel_type();
            let raw = factory.create_texture_raw(desc, Some(cty), None).unwrap();
            let levels = (0, raw.get_info().levels - 1);
            let tex = Typed::new(raw);
            let view = factory.view_texture_as_shader_resource::<T>(&tex, levels, gfx::format::Swizzle::new()).unwrap();
            (tex, view)
        };

        #[cfg(all(target_os = "windows", feature="dx11"))]
        let data = vec![0u8; size[0] * size[1] * RGBA_STRIDE];
        #[cfg(not(feature = "dx11"))]
        let data = vec![];

        Ok(ImageTexture {
            handle: surface,
            srv: view,
            filter: filter,
            format: format,
            data: data,
        })
    }

    #[inline(always)]
    pub fn get_size(&self) -> (usize, usize) {
        let (w, h, _, _) = self.handle.get_info().kind.get_dimensions();
        (w as usize, h as usize)
    }
}*/

pub struct Capabilities {
    pub supports_multisampling: bool,
}

#[derive(Debug)]
pub struct BoundTextures {
    pub color0: (TextureId, TextureStorage),
    pub color1: (TextureId, TextureStorage),
    pub color2: (TextureId, TextureStorage),
    pub cache_a8: (TextureId, TextureStorage),
    pub cache_rgba8: (TextureId, TextureStorage),
    pub shared_cache_a8: (TextureId, TextureStorage),
}

/*pub struct RenderPass<B: gfx::Backend> {
    pub handle: B::RenderPass,
    attachments: Vec<String>,
    subpasses: Vec<String>,
}

pub struct Resources<B: gfx::Backend> {
    pub buffers: HashMap<String, (B::Buffer, B::Memory)>,
    pub images: HashMap<String, Image<B>>,
    pub image_views: HashMap<String, B::ImageView>,
    pub render_passes: HashMap<String, RenderPass<B>>,
    pub framebuffers: HashMap<String, (B::Framebuffer, gfx::device::Extent)>,
    pub desc_set_layouts: HashMap<String, B::DescriptorSetLayout>,
    pub desc_pools: HashMap<String, B::DescriptorPool>,
    pub desc_sets: HashMap<String, B::DescriptorSet>,
    pub pipeline_layouts: HashMap<String, B::PipelineLayout>,
}*/

pub struct Device<B: gfx::Backend> {
    //adapter: gfx::Adapter<B>,
    //gpu: gfx::Gpu<B>,
    /*pub factory: backend::Factory,
    pub encoder: gfx::Encoder<R,CB>,
    pub dither: DataTexture<A8>,
    pub cache_a8_textures: HashMap<TextureId, CacheTexture<Rgba8>>,
    pub cache_rgba8_textures: HashMap<TextureId, CacheTexture<Rgba8>>,
    pub image_textures: HashMap<TextureId, ImageTexture<Rgba8>>,
    pub bound_textures: BoundTextures,
    pub layers: DataTexture<Rgba32F>,
    pub render_tasks: DataTexture<Rgba32F>,
    pub resource_cache: DataTexture<Rgba32F>,
    pub main_color: gfx::handle::RenderTargetView<R, ColorFormat>,
    pub main_depth: gfx::handle::DepthStencilView<R, DepthFormat>,
    pub vertex_buffer: gfx::handle::Buffer<R, Position>,
    pub slice: gfx::Slice<R>,*/

    //pub resources: Resources<B>,
    pub layers_image_upload_memory: B::Memory,
    pub layers_image_upload_buffer: B::Buffer,
    pub layers_image: B::Image,
    pub layers_image_srv: B::ImageView,

    pub render_tasks_image_upload_memory: B::Memory,
    pub render_tasks_image_upload_buffer: B::Buffer,
    pub render_tasks_image: B::Image,
    pub render_tasks_image_srv: B::ImageView,

    pub resource_cache_image_upload_memory: B::Memory,
    pub resource_cache_image_upload_buffer: B::Buffer,
    pub resource_cache_image: B::Image,
    pub resource_cache_image_srv: B::ImageView,

    pub sampler: (B::Sampler, B::Sampler),
    pub device: B::Device,
    pub queue_group: gfx::QueueGroup<B, gfx::queue::Graphics>,
    pub command_pool: gfx::CommandPool<B, gfx::queue::Graphics>,
    //pub upload_buffers: HashMap<String, (B::Buffer, B::Memory)>,
    //pub download_type: gfx::MemoryType,

    pub render_pass: B::RenderPass,
    pub set_layout: B::DescriptorSetLayout,
    pub pipeline_layout: B::PipelineLayout,
    pub pipelines: Vec<Result<B::GraphicsPipeline, gfx::pso::CreationError>>,
    pub desc_pool: B::DescriptorPool,
    pub desc_sets: Vec<B::DescriptorSet>,
    pub buffer_memory: B::Memory,
    pub vertex_buffer: B::Buffer,
    pub ibuffer_memory: B::Memory,
    pub instance_buffer: B::Buffer,
    pub lbuffer_memory: B::Memory,
    pub locals_buffer: B::Buffer,
    pub vs_module: B::ShaderModule,
    pub fs_module: B::ShaderModule,
    //pub frame_semaphore: B::Semaphore,
    pub framebuffers: Vec<B::Framebuffer>,
    pub frame_images: Vec<(B::Image, B::ImageView)>,
    pub swap_chain: Box<B::Swapchain>,
    pub viewport: command::Viewport,

    // Only used on dx11
    image_batch_set: HashSet<TextureId>,

    // device state
    device_pixel_ratio: f32,

    // HW or API capabilties
    capabilities: Capabilities,

    // debug
    inside_frame: bool,

    // resources
    resource_override_path: Option<PathBuf>,

    max_texture_size: u32,

    // Frame counter. This is used to map between CPU
    // frames and GPU frames.
    frame_id: FrameId,
}

pub struct DeviceInitParams {
    //pub window: 
    /*pub device: BackendDevice,
    pub factory: backend::Factory,
    pub main_color: gfx::handle::RenderTargetView<R, ColorFormat>,
    pub main_depth: gfx::handle::DepthStencilView<R, DepthFormat>,*/
}

impl<B: gfx::Backend> Device<B> {
    pub fn new(
        resource_override_path: Option<PathBuf>,
        window: &winit::Window,
        instance: &back::Instance,
        surface: &mut <back::Backend as gfx::Backend>::Surface,
        _file_changed_handler: Box<FileWatcherHandler>)
    -> Device<back::Backend> {
        let max_texture_size = 1024;

        let window_size = window.get_inner_size_pixels().unwrap();
        let pixel_width = window_size.0 as u16;
        let pixel_height = window_size.1 as u16;

        // instantiate backend
        let mut adapters = instance.enumerate_adapters();

        for adapter in &adapters {
            println!("{:?}", adapter.info);
        }

        let adapter = adapters.remove(0);
        let surface_format = surface
            .capabilities_and_formats(&adapter.physical_device)
            .1
            .into_iter()
            .find(|format| format.1 == ChannelType::Srgb)
            .unwrap();

        /*let mut gpu = adapter
            .open_with(|family| {
                if family.supports_graphics() && surface.supports_queue_family(family) {
                    Some(1)
                } else {
                    None
                }
            });*/
        let Gpu { device, mut queue_groups, memory_types, .. } =
            adapter.open_with(|family| {
                if family.supports_graphics() {
                    Some(1)
                } else { None }
            });

        let mut queue_group = gfx::QueueGroup::<_, gfx::Graphics>::new(queue_groups.remove(0));
        let mut command_pool = device.create_command_pool_typed(&queue_group, pool::CommandPoolCreateFlags::empty(), 32);
        command_pool.reset();
        //let mut queue = queue_group.queues.remove(0);

        println!("{:?}", surface_format);
        let swap_config = SwapchainConfig::new()
            .with_color(surface_format);
        let (mut swap_chain, backbuffer) = device.create_swapchain(surface, swap_config);

        let render_pass = {
            let attachment = pass::Attachment {
                format: surface_format,
                ops: pass::AttachmentOps::new(pass::AttachmentLoadOp::Clear, pass::AttachmentStoreOp::Store),
                stencil_ops: pass::AttachmentOps::DONT_CARE,
                layouts: i::ImageLayout::Undefined .. i::ImageLayout::Present,
            };

            let subpass = pass::SubpassDesc {
                colors: &[(0, i::ImageLayout::ColorAttachmentOptimal)],
                depth_stencil: None,
                inputs: &[],
                preserves: &[],
            };

            let dependency = pass::SubpassDependency {
                passes: pass::SubpassRef::External .. pass::SubpassRef::Pass(0),
                stages: PipelineStage::COLOR_ATTACHMENT_OUTPUT .. PipelineStage::COLOR_ATTACHMENT_OUTPUT,
                accesses: i::Access::empty() .. (i::Access::COLOR_ATTACHMENT_READ | i::Access::COLOR_ATTACHMENT_WRITE),
            };

            device.create_render_pass(&[attachment], &[subpass], &[dependency])
        };

        // Framebuffer and render target creation
        let (frame_images, framebuffers) = match backbuffer {
            Backbuffer::Images(images) => {
                let extent = d::Extent { width: pixel_width as _, height: pixel_height as _, depth: 1 };
                let pairs = images
                    .into_iter()
                    .map(|image| {
                        let rtv = device.create_image_view(&image, surface_format, Swizzle::NO, COLOR_RANGE.clone()).unwrap();
                        (image, rtv)
                    })
                    .collect::<Vec<_>>();
                let fbos = pairs
                    .iter()
                    .map(|&(_, ref rtv)| {
                        device.create_framebuffer(&render_pass, &[rtv], extent).unwrap()
                    })
                    .collect();
                (pairs, fbos)
            }
            Backbuffer::Framebuffer(fbo) => {
                (Vec::new(), vec![fbo])
            }
        };

        // Setup renderpass and pipeline
        #[cfg(any(feature = "vulkan", feature = "dx12", feature = "metal"))]
        let vs_module = device
            .create_shader_module(include_bytes!("../data/rect_vert.spv"))
            .unwrap();
        #[cfg(any(feature = "vulkan", feature = "dx12", feature = "metal"))]
        let fs_module = device
            .create_shader_module(include_bytes!("../data/rect_frag.spv"))
            .unwrap();

        let set_layout = device.create_descriptor_set_layout(&[
                pso::DescriptorSetLayoutBinding { // Locals
                    binding: 0,
                    ty: pso::DescriptorType::UniformBuffer,
                    count: 1,
                    stage_flags: ShaderStageFlags::VERTEX,
                },
                pso::DescriptorSetLayoutBinding { // tColor0
                    binding: 3,
                    ty: pso::DescriptorType::SampledImage,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // sColor0
                    binding: 4,
                    ty: pso::DescriptorType::Sampler,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // tCacheA8
                    binding: 5,
                    ty: pso::DescriptorType::SampledImage,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // sCacheA8
                    binding: 6,
                    ty: pso::DescriptorType::Sampler,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // tCacheRGBA8
                    binding: 7,
                    ty: pso::DescriptorType::SampledImage,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // sCacheRGBA8
                    binding: 8,
                    ty: pso::DescriptorType::Sampler,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // tSharedCacheA8
                    binding: 9,
                    ty: pso::DescriptorType::SampledImage,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // sSharedCacheA8
                    binding: 10,
                    ty: pso::DescriptorType::Sampler,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // tResourceCache
                    binding: 11,
                    ty: pso::DescriptorType::SampledImage,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // sResourceCache
                    binding: 12,
                    ty: pso::DescriptorType::Sampler,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // tLayers
                    binding: 13,
                    ty: pso::DescriptorType::SampledImage,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // sLayers
                    binding: 14,
                    ty: pso::DescriptorType::Sampler,
                    count: 1,
                    stage_flags: ShaderStageFlags::ALL,
                },
                pso::DescriptorSetLayoutBinding { // tRenderTasks
                    binding: 15,
                    ty: pso::DescriptorType::SampledImage,
                    count: 1,
                    stage_flags: ShaderStageFlags::VERTEX,
                },
                pso::DescriptorSetLayoutBinding { // sRenderTasks
                    binding: 16,
                    ty: pso::DescriptorType::Sampler,
                    count: 1,
                    stage_flags: ShaderStageFlags::VERTEX,
                },
            ],
        );

        let pipeline_layout = device.create_pipeline_layout(&[&set_layout], &[]);

        let pipelines = {
            let (vs_entry, fs_entry) = (
                pso::EntryPoint::<back::Backend> { entry: ENTRY_NAME, module: &vs_module, specialization: &[] },
                pso::EntryPoint::<back::Backend> { entry: ENTRY_NAME, module: &fs_module, specialization: &[] },
            );

            let shader_entries = pso::GraphicsShaderSet {
                vertex: vs_entry,
                hull: None,
                domain: None,
                geometry: None,
                fragment: Some(fs_entry),
            };

            let subpass = Subpass { index: 0, main_pass: &render_pass };

            let mut pipeline_desc = pso::GraphicsPipelineDesc::new(
                shader_entries,
                Primitive::TriangleList,
                pso::Rasterizer::FILL,
                &pipeline_layout,
                subpass,
            );
            pipeline_desc.blender.targets.push(pso::ColorBlendDesc(
                pso::ColorMask::ALL,
                pso::BlendState::ALPHA,
            ));
            pipeline_desc.vertex_buffers.push(pso::VertexBufferDesc {
                stride: std::mem::size_of::<Vertex>() as u32,
                rate: 0, // VertexBuffer
            });
            pipeline_desc.vertex_buffers.push(pso::VertexBufferDesc {
                stride: std::mem::size_of::<PrimitiveInstance>() as u32,
                rate: 1, // InstanceBuffer
            });

            pipeline_desc.attributes.push(pso::AttributeDesc { // aPosition
                location: 0,
                binding: 0,
                element: pso::Element {
                    format: Vec3::<f32>::SELF,
                    offset: 0,
                },
            });
            pipeline_desc.attributes.push(pso::AttributeDesc { // aDataA
                location: 4,
                binding: 1,
                element: pso::Element {
                    format: Vec4::<i32>::SELF,
                    offset: 0,
                },
            });
            pipeline_desc.attributes.push(pso::AttributeDesc { // aDataB
                location: 5,
                binding: 1,
                element: pso::Element {
                    format: Vec4::<i32>::SELF,
                    offset: 16,
                },
            });

            device.create_graphics_pipelines(&[pipeline_desc])
        };

        println!("pipelines: {:?}", pipelines);

        let mut desc_pool = device.create_descriptor_pool(
            1, // sets
            &[
                pso::DescriptorRangeDesc {
                    ty: pso::DescriptorType::UniformBuffer,
                    count: 1,
                },
                pso::DescriptorRangeDesc {
                    ty: pso::DescriptorType::SampledImage,
                    count: 7,
                },
                pso::DescriptorRangeDesc {
                    ty: pso::DescriptorType::Sampler,
                    count: 7,
                },
            ],
        );

        let desc_sets = desc_pool.allocate_sets(&[&set_layout]);

        // Buffer allocations
        println!("Memory types: {:?}", memory_types);

        let buffer_stride = std::mem::size_of::<Vertex>() as u64;
        let buffer_len = QUAD.len() as u64 * buffer_stride;

        let buffer_unbound = device.create_buffer(buffer_len, buffer::Usage::VERTEX).unwrap();
        println!("{:?}", buffer_unbound);
        let buffer_req = device.get_buffer_requirements(&buffer_unbound);
        let upload_type =
            memory_types.iter().find(|mem_type| {
                buffer_req.type_mask & (1 << mem_type.id) != 0 &&
                mem_type.properties.contains(m::Properties::CPU_VISIBLE)
            }).unwrap();

        let buffer_memory = device.allocate_memory(upload_type, buffer_req.size).unwrap();
        let vertex_buffer = device.bind_buffer_memory(&buffer_memory, 0, buffer_unbound).unwrap();

        // TODO: check transitions: read/write mapping and vertex buffer read
        {
            let mut vertices = device
                .acquire_mapping_writer::<Vertex>(&vertex_buffer, 0..buffer_len)
                .unwrap();
            vertices.copy_from_slice(&QUAD);
            device.release_mapping_writer(vertices);
        }

        let ibuffer_stride = std::mem::size_of::<PrimitiveInstance>() as u64;
        //let ibuffer_len = MAX_INSTANCE_COUNT * ibuffer_stride;
        let ibuffer_len = 6 * ibuffer_stride;

        let ibuffer_unbound = device.create_buffer(ibuffer_len, buffer::Usage::VERTEX).unwrap();
        println!("{:?}", ibuffer_unbound);
        let ibuffer_req = device.get_buffer_requirements(&ibuffer_unbound);
        let iupload_type =
            memory_types.iter().find(|mem_type| {
                ibuffer_req.type_mask & (1 << mem_type.id) != 0 &&
                mem_type.properties.contains(m::Properties::CPU_VISIBLE)
            }).unwrap();

        let ibuffer_memory = device.allocate_memory(iupload_type, ibuffer_req.size).unwrap();
        let instance_buffer = device.bind_buffer_memory(&ibuffer_memory, 0, ibuffer_unbound).unwrap();

        // TODO: check transitions: read/write mapping and vertex buffer read
        {
            let mut instances = device
                .acquire_mapping_writer::<PrimitiveInstance>(&instance_buffer, 0..ibuffer_len)
                .unwrap();
            instances[0] = PrimitiveInstance {
                aDataA: [1020, 0, 2147483647, 0],
                aDataB: [0, 0, 0, 0],
            };
            instances[1] = PrimitiveInstance {
                aDataA: [1020, 0, 2147483647, 0],
                aDataB: [0, 0, 0, 0],
            };
            instances[2] = PrimitiveInstance {
                aDataA: [1020, 0, 2147483647, 0],
                aDataB: [0, 0, 0, 0],
            };
            instances[3] = PrimitiveInstance {
                aDataA: [1020, 0, 2147483647, 0],
                aDataB: [0, 0, 0, 0],
            };
            instances[4] = PrimitiveInstance {
                aDataA: [1020, 0, 2147483647, 0],
                aDataB: [0, 0, 0, 0],
            };
            instances[5] = PrimitiveInstance {
                aDataA: [1020, 0, 2147483647, 0],
                aDataB: [0, 0, 0, 0],
            };
            device.release_mapping_writer(instances);
        }

        let lbuffer_stride = std::mem::size_of::<Locals>() as u64;
        let lbuffer_len = lbuffer_stride;
        let lbuffer_unbound = device.create_buffer(lbuffer_len, buffer::Usage::UNIFORM).unwrap();
        let lbuffer_req = device.get_buffer_requirements(&lbuffer_unbound);
        let mem_type =
            memory_types.iter().find(|mem_type| {
                lbuffer_req.type_mask & (1 << mem_type.id) != 0 &&
                mem_type.properties.contains(m::Properties::CPU_VISIBLE)
            }).unwrap();

        let lbuffer_memory = device.allocate_memory(mem_type, lbuffer_req.size).unwrap();
        let locals_buffer = device.bind_buffer_memory(&lbuffer_memory, 0, lbuffer_unbound).unwrap();

        // TODO: check transitions: read/write mapping and vertex buffer read
        {
            println!("{:?} {:?}", lbuffer_len, std::mem::size_of::<Locals>() as u64);
            let mut locals = device
                .acquire_mapping_writer::<Locals>(&locals_buffer, 0..lbuffer_len)
                .unwrap();
            /*let transform: [[f32; 4]; 4] = [
                [0.00195, 0.0, -0.5, -1.0],
                [0.0, 0.0026, 0.5, 1.0],
                [0.0, 0.0, 0.0, 0.0],
                [0.0, 0.0, 0.5, 1.0]];*/
            let transform: [[f32; 4]; 4] = [
                [0.00195, 0.00, 0.00, 0.00],
                [0.00, 0.0026, 0.00, 0.00],
                [-0.50, 0.50, 0.00, 0.50],
                [-1.00, 1.00, 0.00, 1.00]];
            locals[0] = Locals {
                uMode: 0i32,
                uTransform: transform.into(),
                uDevicePixelRatio: DEVICE_PIXEL_RATIO,
            };
            device.release_mapping_writer(locals);
        }

        // Textures

        let (width, height) = (LAYER_TEXTURE_WIDTH as u32, 64u32);
        let kind = i::Kind::D2(width as i::Size, height as i::Size, i::AaMode::Single);
        let row_alignment_mask = device.get_limits().min_buffer_copy_pitch_alignment as u32 - 1;
        let image_stride = 4usize;
        let row_pitch = (width * image_stride as u32 + row_alignment_mask) & !row_alignment_mask;
        let upload_size = (height * row_pitch) as u64;
        println!("upload row pitch {}, total size {}", row_pitch, upload_size);

        let layers_image_upload_memory = device.allocate_memory(upload_type, upload_size).unwrap();
        let layers_image_upload_buffer = {
            let buffer = device.create_buffer(upload_size, buffer::Usage::TRANSFER_SRC).unwrap();
            device.bind_buffer_memory(&layers_image_upload_memory, 0, buffer).unwrap()
        };

        let image_unbound = device.create_image(kind, 1, ColorFormat::SELF, i::Usage::TRANSFER_DST | i::Usage::SAMPLED).unwrap(); // TODO: usage
        println!("{:?}", image_unbound);
        let image_req = device.get_image_requirements(&image_unbound);

        let device_type = memory_types
            .iter()
            .find(|memory_type| {
                image_req.type_mask & (1 << memory_type.id) != 0 &&
                memory_type.properties.contains(m::Properties::DEVICE_LOCAL)
            })
            .unwrap();
        let image_memory = device.allocate_memory(device_type, image_req.size).unwrap();

        let layers_image = device.bind_image_memory(&image_memory, 0, image_unbound).unwrap();
        let layers_image_srv = device.create_image_view(&layers_image, ColorFormat::SELF, Swizzle::NO, COLOR_RANGE.clone()).unwrap();

        let (width, height) = (max_texture_size as u32, max_texture_size as u32);
        let kind = i::Kind::D2(width as i::Size, height as i::Size, i::AaMode::Single);
        let row_alignment_mask = device.get_limits().min_buffer_copy_pitch_alignment as u32 - 1;
        let image_stride = 4usize;
        let row_pitch = (width * image_stride as u32 + row_alignment_mask) & !row_alignment_mask;
        let upload_size = (height * row_pitch) as u64;
        println!("upload row pitch {}, total size {}", row_pitch, upload_size);

        let resource_cache_image_upload_memory = device.allocate_memory(upload_type, upload_size).unwrap();
        let resource_cache_image_upload_buffer = {
            let buffer = device.create_buffer(upload_size, buffer::Usage::TRANSFER_SRC).unwrap();
            device.bind_buffer_memory(&resource_cache_image_upload_memory, 0, buffer).unwrap()
        };

        let image_unbound = device.create_image(kind, 1, ColorFormat::SELF, i::Usage::TRANSFER_DST | i::Usage::SAMPLED).unwrap(); // TODO: usage
        println!("{:?}", image_unbound);
        let image_req = device.get_image_requirements(&image_unbound);

        let device_type = memory_types
            .iter()
            .find(|memory_type| {
                image_req.type_mask & (1 << memory_type.id) != 0 &&
                memory_type.properties.contains(m::Properties::DEVICE_LOCAL)
            })
            .unwrap();
        let image_memory = device.allocate_memory(device_type, image_req.size).unwrap();

        let resource_cache_image = device.bind_image_memory(&image_memory, 0, image_unbound).unwrap();
        let resource_cache_image_srv = device.create_image_view(&resource_cache_image, ColorFormat::SELF, Swizzle::NO, COLOR_RANGE.clone()).unwrap();

        let (width, height) = (RENDER_TASK_TEXTURE_WIDTH as u32, TEXTURE_HEIGTH as u32);
        let kind = i::Kind::D2(width as i::Size, height as i::Size, i::AaMode::Single);
        let row_alignment_mask = device.get_limits().min_buffer_copy_pitch_alignment as u32 - 1;
        let image_stride = 4usize;
        let row_pitch = (width * image_stride as u32 + row_alignment_mask) & !row_alignment_mask;
        let upload_size = (height * row_pitch) as u64;
        println!("upload row pitch {}, total size {}", row_pitch, upload_size);

        let render_tasks_image_upload_memory = device.allocate_memory(upload_type, upload_size).unwrap();
        let render_tasks_image_upload_buffer = {
            let buffer = device.create_buffer(upload_size, buffer::Usage::TRANSFER_SRC).unwrap();
            device.bind_buffer_memory(&render_tasks_image_upload_memory, 0, buffer).unwrap()
        };

        let image_unbound = device.create_image(kind, 1, ColorFormat::SELF, i::Usage::TRANSFER_DST | i::Usage::SAMPLED).unwrap(); // TODO: usage
        println!("{:?}", image_unbound);
        let image_req = device.get_image_requirements(&image_unbound);

        let device_type = memory_types
            .iter()
            .find(|memory_type| {
                image_req.type_mask & (1 << memory_type.id) != 0 &&
                memory_type.properties.contains(m::Properties::DEVICE_LOCAL)
            })
            .unwrap();
        let image_memory = device.allocate_memory(device_type, image_req.size).unwrap();

        let render_tasks_image = device.bind_image_memory(&image_memory, 0, image_unbound).unwrap();
        let render_tasks_image_srv = device.create_image_view(&render_tasks_image, ColorFormat::SELF, Swizzle::NO, COLOR_RANGE.clone()).unwrap();

        // Samplers

        let sampler_linear = device.create_sampler(
            i::SamplerInfo::new(
                i::FilterMethod::Bilinear,
                i::WrapMode::Tile,
            )
        );

        let sampler_nearest = device.create_sampler(
            i::SamplerInfo::new(
                i::FilterMethod::Scale,
                i::WrapMode::Tile,
            )
        );

        device.update_descriptor_sets(&[
            pso::DescriptorSetWrite {
                set: &desc_sets[0],
                binding: 0,
                array_offset: 0,
                write: pso::DescriptorWrite::UniformBuffer(vec![
                    (&locals_buffer, 0..std::mem::size_of::<Locals>() as u64),
                ]),
            },
            pso::DescriptorSetWrite {
                set: &desc_sets[0],
                binding: 11,
                array_offset: 0,
                write: pso::DescriptorWrite::SampledImage(vec![(&resource_cache_image_srv, i::ImageLayout::Undefined)]),
            },
            pso::DescriptorSetWrite {
                set: &desc_sets[0],
                binding: 12,
                array_offset: 0,
                write: pso::DescriptorWrite::Sampler(vec![&sampler_nearest]),
            },
            pso::DescriptorSetWrite {
                set: &desc_sets[0],
                binding: 13,
                array_offset: 0,
                write: pso::DescriptorWrite::SampledImage(vec![(&layers_image_srv, i::ImageLayout::Undefined)]),
            },
            pso::DescriptorSetWrite {
                set: &desc_sets[0],
                binding: 14,
                array_offset: 0,
                write: pso::DescriptorWrite::Sampler(vec![&sampler_nearest]),
            },
            pso::DescriptorSetWrite {
                set: &desc_sets[0],
                binding: 15,
                array_offset: 0,
                write: pso::DescriptorWrite::SampledImage(vec![(&render_tasks_image_srv, i::ImageLayout::Undefined)]),
            },
            pso::DescriptorSetWrite {
                set: &desc_sets[0],
                binding: 16,
                array_offset: 0,
                write: pso::DescriptorWrite::Sampler(vec![&sampler_nearest]),
            },
        ]);

        // Rendering setup
        let viewport = command::Viewport {
            rect: command::Rect {
                x: 0, y: 0,
                w: pixel_width, h: pixel_height,
            },
            depth: 0.0 .. 1.0,
        };

        /*#[cfg(all(target_os = "windows", feature="dx11"))]
        let encoder = params.factory.create_command_buffer_native().into();

        #[cfg(not(feature = "dx11"))]
        let encoder = params.factory.create_command_buffer().into();
        
        let (x0, y0, x1, y1) = (0.0, 0.0, 1.0, 1.0);
        let quad_indices: &[u16] = &[ 0, 1, 2, 2, 1, 3 ];
        let quad_vertices = [
            Position::new([x0, y0]),
            Position::new([x1, y0]),
            Position::new([x0, y1]),
            Position::new([x1, y1]),
        ];

        let (vertex_buffer, mut slice) = params.factory.create_vertex_buffer_with_slice(&quad_vertices, quad_indices);
        slice.instances = Some((MAX_INSTANCE_COUNT as u32, 0));

        let wrap_mode = (gfx::texture::WrapMode::Clamp, gfx::texture::WrapMode::Clamp, gfx::texture::WrapMode::Tile);
        let mut sampler_info = gfx::texture::SamplerInfo::new(gfx::texture::FilterMethod::Scale, gfx::texture::WrapMode::Clamp);
        sampler_info.wrap_mode = wrap_mode;
        let sampler_nearest = params.factory.create_sampler(sampler_info);
        sampler_info.filter = gfx::texture::FilterMethod::Bilinear;
        let sampler_linear = params.factory.create_sampler(sampler_info);

        let dither_matrix: [u8; 64] = [
            00, 48, 12, 60, 03, 51, 15, 63,
            32, 16, 44, 28, 35, 19, 47, 31,
            08, 56, 04, 52, 11, 59, 07, 55,
            40, 24, 36, 20, 43, 27, 39, 23,
            02, 50, 14, 62, 01, 49, 13, 61,
            34, 18, 46, 30, 33, 17, 45, 29,
            10, 58, 06, 54, 09, 57, 05, 53,
            42, 26, 38, 22, 41, 25, 37, 21
        ];
        let dither_tex = DataTexture::create(&mut params.factory, [8, 8], Some((&[&dither_matrix], gfx::texture::Mipmap::Provided))).unwrap();
        let dummy_cache_a8_tex = CacheTexture::create(&mut params.factory, [1, 1]).unwrap();
        let dummy_cache_rgba8_tex = CacheTexture::create(&mut params.factory, [1, 1]).unwrap();
        let dummy_image_tex = ImageTexture::create(&mut params.factory, [1, 1], 1, TextureFilter::Linear, ImageFormat::BGRA8).unwrap();
        let layers_tex = DataTexture::create(&mut params.factory, [LAYER_TEXTURE_WIDTH, 64], None).unwrap();
        let render_tasks_tex = DataTexture::create(&mut params.factory, [RENDER_TASK_TEXTURE_WIDTH, TEXTURE_HEIGTH], None).unwrap();
        let resource_cache_tex = DataTexture::create(&mut params.factory, [max_texture_size, max_texture_size], None).unwrap();

        let mut cache_a8_textures = HashMap::new();
        cache_a8_textures.insert(DUMMY_ID, dummy_cache_a8_tex);
        let mut cache_rgba8_textures = HashMap::new();
        cache_rgba8_textures.insert(DUMMY_ID, dummy_cache_rgba8_tex);
        let mut image_textures = HashMap::new();
        image_textures.insert(DUMMY_ID, dummy_image_tex);

        let bound_textures = BoundTextures {
            color0: (DUMMY_ID, TextureStorage::Image),
            color1: (DUMMY_ID, TextureStorage::Image),
            color2: (DUMMY_ID, TextureStorage::Image),
            cache_a8: (DUMMY_ID, TextureStorage::CacheA8),
            cache_rgba8: (DUMMY_ID, TextureStorage::CacheRGBA8),
            shared_cache_a8: (DUMMY_ID, TextureStorage::CacheA8),
        };*/

        let dev = Device {
            //adapter: adapter,
            //gpu: gpu,
            device: device,
            sampler: (sampler_nearest, sampler_linear),
            /*factory: params.factory,
            encoder: encoder,
            dither: dither_tex,
            cache_a8_textures: cache_a8_textures,
            cache_rgba8_textures: cache_rgba8_textures,
            image_textures: image_textures,
            bound_textures: bound_textures,
            //dummy_cache_a8: dummy_cache_a8_tex,
            //dummy_cache_rgba8: dummy_cache_rgba8_tex,
            main_color: params.main_color,
            main_depth: params.main_depth,
            vertex_buffer: vertex_buffer,
            slice: slice,*/
            layers_image_upload_memory: layers_image_upload_memory,
            layers_image_upload_buffer: layers_image_upload_buffer,
            render_tasks_image_upload_memory: render_tasks_image_upload_memory,
            render_tasks_image_upload_buffer: render_tasks_image_upload_buffer,
            resource_cache_image_upload_memory: resource_cache_image_upload_memory,
            resource_cache_image_upload_buffer: resource_cache_image_upload_buffer,
            layers_image: layers_image,
            layers_image_srv: layers_image_srv,
            render_tasks_image: render_tasks_image,
            render_tasks_image_srv: render_tasks_image_srv,
            resource_cache_image: resource_cache_image,
            resource_cache_image_srv: resource_cache_image_srv,
            command_pool: command_pool,
            queue_group: queue_group,
            viewport: viewport,
            render_pass: render_pass,
            framebuffers: framebuffers,
            frame_images: frame_images,
            set_layout: set_layout,
            desc_pool: desc_pool,
            desc_sets: desc_sets,
            pipeline_layout: pipeline_layout,
            pipelines: pipelines,
            buffer_memory: buffer_memory,
            vertex_buffer: vertex_buffer,
            ibuffer_memory: ibuffer_memory,
            instance_buffer: instance_buffer,
            lbuffer_memory: lbuffer_memory,
            locals_buffer: locals_buffer,
            swap_chain: Box::new(swap_chain),
            //frame_semaphore: frame_semaphore,
            vs_module: vs_module,
            fs_module: fs_module,
            image_batch_set: HashSet::new(),
            resource_override_path,
            // This is initialized to 1 by default, but it is set
            // every frame by the call to begin_frame().
            device_pixel_ratio: 1.0,
            inside_frame: false,

            capabilities: Capabilities {
                supports_multisampling: false, //TODO
            },

            max_texture_size: max_texture_size as u32,
            frame_id: FrameId(0),
        };
        dev
    }

    pub fn swap_buffers(&mut self) {
        println!("swap_buffers");
        let mut frame_semaphore = self.device.create_semaphore();
        let mut frame_fence = self.device.create_fence(false); // TODO: remove
        {
            self.device.reset_fences(&[&frame_fence]);
            self.command_pool.reset();
            let frame = self.swap_chain.acquire_frame(FrameSync::Semaphore(&mut frame_semaphore));

            // Rendering
            let submit = {
                let mut cmd_buffer = self.command_pool.acquire_command_buffer();

                cmd_buffer.set_viewports(&[self.viewport.clone()]);
                cmd_buffer.set_scissors(&[self.viewport.rect]);
                cmd_buffer.bind_graphics_pipeline(&self.pipelines[0].as_ref().unwrap());
                cmd_buffer.bind_vertex_buffers(pso::VertexBufferSet(vec![(&self.vertex_buffer, 0), (&self.instance_buffer, 0)]));
                cmd_buffer.bind_graphics_descriptor_sets(&self.pipeline_layout, 0, &[&self.desc_sets[0]]);

                {
                    let mut encoder = cmd_buffer.begin_renderpass_inline(
                        &self.render_pass,
                        &self.framebuffers[frame.id()],
                        self.viewport.rect,
                        &[command::ClearValue::Color(command::ClearColor::Float([0.25, 0.25, 0.5, 1.0]))],
                    );
                    encoder.draw(0..6, 0..6);
                }

                cmd_buffer.finish()
            };

            let submission = Submission::new()
                .wait_on(&[(&mut frame_semaphore, PipelineStage::BOTTOM_OF_PIPE)])
                .submit(&[submit]);
            self.queue_group.queues[0].submit(submission, Some(&mut frame_fence));

            // TODO: replace with semaphore
            self.device.wait_for_fences(&[&frame_fence], d::WaitFor::All, !0);

            // present frame
            self.swap_chain.present(&mut self.queue_group.queues[0], &[]);
        }

        self.device.destroy_fence(frame_fence);
        self.device.destroy_semaphore(frame_semaphore);
    }

    /*pub fn dither(&mut self) -> &DataTexture<A8> {
        &self.dither
    }

    pub fn dummy_cache_a8(&self) -> &CacheTexture<Rgba8> {
        self.cache_a8_textures.get(&DUMMY_ID).unwrap()
    }

    pub fn dummy_cache_rgba8(&self) -> &CacheTexture<Rgba8> {
        self.cache_rgba8_textures.get(&DUMMY_ID).unwrap()
    }

    pub fn dummy_image(&mut self) -> &ImageTexture<Rgba8> {
        self.image_textures.get(&DUMMY_ID).unwrap()
    }

    pub fn get_texture_srv_and_sampler(&mut self, sampler: TextureSampler)
        -> (gfx::handle::ShaderResourceView<R, [f32; 4]>, gfx::handle::Sampler<R>)
    {
        let (id, storage) = match sampler {
            TextureSampler::Color0 => self.bound_textures.color0,
            TextureSampler::Color1 => self.bound_textures.color1,
            TextureSampler::Color2 => self.bound_textures.color2,
            TextureSampler::CacheA8 => self.bound_textures.cache_a8,
            TextureSampler::CacheRGBA8 => self.bound_textures.cache_rgba8,
            TextureSampler::SharedCacheA8 => self.bound_textures.shared_cache_a8,
            _ => unreachable!(),
        };
        match storage {
            TextureStorage::Image => {
                let tex = self.image_textures.get(&id).unwrap();
                let sampler = match tex.filter {
                    TextureFilter::Nearest => self.sampler.0.clone(),
                    TextureFilter::Linear => self.sampler.1.clone(),
                };
                (tex.srv.clone(), sampler)
            },
            TextureStorage::CacheRGBA8 => (self.cache_rgba8_textures.get(&id).unwrap().srv.clone(), self.sampler.1.clone()),
            TextureStorage::CacheA8 => (self.cache_a8_textures.get(&id).unwrap().srv.clone(), self.sampler.0.clone()),
        }
    }

    pub fn get_texture_rtv(&mut self, sampler: TextureSampler)
        -> gfx::handle::RenderTargetView<R, Rgba8>
    {
        let (id, storage) = match sampler {
            TextureSampler::Color0 => self.bound_textures.color0,
            TextureSampler::Color1 => self.bound_textures.color1,
            TextureSampler::Color2 => self.bound_textures.color2,
            TextureSampler::CacheA8 => self.bound_textures.cache_a8,
            TextureSampler::CacheRGBA8 => self.bound_textures.cache_rgba8,
            TextureSampler::SharedCacheA8 => self.bound_textures.shared_cache_a8,
            _ => unreachable!(),
        };
        match storage {
            TextureStorage::CacheA8 => self.cache_a8_textures.get(&id).unwrap().rtv.clone(),
            TextureStorage::CacheRGBA8 => self.cache_rgba8_textures.get(&id).unwrap().rtv.clone(),
            TextureStorage::Image => unreachable!(),
        }
    }*/

    pub fn read_pixels(&mut self, rect: DeviceUintRect, output: &mut [u8]) {
        // TODO add bgra flag
        /*self.encoder.flush(&mut self.device);
        let tex = self.main_color.raw().get_texture();
        let tex_info = tex.get_info().to_raw_image_info(gfx::format::ChannelType::Unorm, 0);
        let (w, h, _, _) = self.main_color.get_dimensions();
        let buf = self.factory.create_buffer::<u8>(w as usize * h as usize * RGBA_STRIDE,
                                                   gfx::buffer::Role::Vertex,
                                                   gfx::memory::Usage::Download,
                                                   gfx::TRANSFER_DST).unwrap();
        self.encoder.copy_texture_to_buffer_raw(tex, None, tex_info, buf.raw(), 0).unwrap();
        self.encoder.flush(&mut self.device);
        {
            let reader = self.factory.read_mapping(&buf).unwrap();
            let data = &*reader;
            for j in 0..rect.size.height as usize {
                for i in 0..rect.size.width as usize {
                    let offset = i * RGBA_STRIDE + j * rect.size.width as usize * RGBA_STRIDE;
                    let src = &data[(j + rect.origin.y as usize) * w as usize * RGBA_STRIDE + (i + rect.origin.x as usize) * RGBA_STRIDE ..];
                    output[offset + 0] = src[0];
                    output[offset + 1] = src[1];
                    output[offset + 2] = src[2];
                    output[offset + 3] = src[3];
                }
            }
        }*/
    }

    pub fn max_texture_size(&self) -> u32 {
        self.max_texture_size
    }

    pub fn get_capabilities(&self) -> &Capabilities {
        &self.capabilities
    }

    pub fn reset_state(&mut self) {
    }

    pub fn begin_frame(&mut self, device_pixel_ratio: f32) -> FrameId {
        debug_assert!(!self.inside_frame);
        self.inside_frame = true;
        self.device_pixel_ratio = device_pixel_ratio;
        self.frame_id
    }

    pub fn bind_texture(&mut self,
                        sampler: TextureSampler,
                        texture: TextureId,
                        storage: TextureStorage) {
        debug_assert!(self.inside_frame);

        /*match sampler {
            TextureSampler::Color0 => self.bound_textures.color0 = (texture, storage),
            TextureSampler::Color1 => self.bound_textures.color1 = (texture, storage),
            TextureSampler::Color2 => self.bound_textures.color2 = (texture, storage),
            TextureSampler::CacheA8 => self.bound_textures.cache_a8 = (texture, storage),
            TextureSampler::CacheRGBA8 => self.bound_textures.cache_rgba8 = (texture, storage),
            TextureSampler::SharedCacheA8 => self.bound_textures.shared_cache_a8 = (texture, storage),
            _ => return
        }*/
    }

    pub fn generate_texture_id(&mut self) -> TextureId {
        use rand::OsRng;

        let mut rng = OsRng::new().unwrap();
        //let mut texture_id = FIRST_UNRESERVED_ID;
        let texture_id = rng.gen_range(FIRST_UNRESERVED_ID, u32::max_value());
        /*while self.cache_a8_textures.contains_key(&texture_id) ||
              self.cache_rgba8_textures.contains_key(&texture_id) ||
              self.image_textures.contains_key(&texture_id) {
            texture_id = rng.gen_range(FIRST_UNRESERVED_ID, u32::max_value());
        }*/
        texture_id
    }

    pub fn create_cache_texture(&mut self, width: u32, height: u32, kind: RenderTargetKind) -> TextureId
    {
        let id = self.generate_texture_id();
        println!("create_cache_texture={:?}", id);
        /*match kind {
            RenderTargetKind::Alpha => {
                let tex = CacheTexture::create(&mut self.factory, [width as usize, height as usize]).unwrap();
                self.cache_a8_textures.insert(id, tex);
            }
            RenderTargetKind::Color => {
                let tex = CacheTexture::create(&mut self.factory, [width as usize, height as usize]).unwrap();
                self.cache_rgba8_textures.insert(id, tex);
            }
        }*/
        id
    }

    pub fn create_image_texture(&mut self, width: u32, height: u32, layer_count: i32, filter: TextureFilter, format: ImageFormat) -> TextureId {
        let id = self.generate_texture_id();
        /*println!("create_image_texture={:?}", id);
        let tex = ImageTexture::create(&mut self.factory, [width as usize, height as usize], layer_count as u16, filter, format).unwrap();
        self.image_textures.insert(id, tex);*/
        id
    }

    pub fn free_texture_storage(&mut self, texture: &TextureId) {
        debug_assert!(self.inside_frame);
    }

    pub fn update_data_texture<T>(&mut self, sampler: TextureSampler, offset: [u16; 2], size: [u16; 2], memory: &[T]) where T: gfx::memory::Pod {
        /*let img_info = gfx::texture::ImageInfoCommon {
            xoffset: offset[0],
            yoffset: offset[1],
            zoffset: 0,
            width: size[0],
            height: size[1],
            depth: 0,
            format: (),
            mipmap: 0,
        };

        let tex = match sampler {
            TextureSampler::ResourceCache => &self.resource_cache.handle,
            TextureSampler::Layers => &self.layers.handle,
            TextureSampler::RenderTasks => &self.render_tasks.handle,
            _=> unreachable!(),
        };
        self.encoder.update_texture::<_, Rgba32F>(tex, None, img_info, gfx::memory::cast_slice(memory)).unwrap();*/
        let buffer = match sampler {
            TextureSampler::ResourceCache => &self.resource_cache_image_upload_buffer,
            TextureSampler::Layers => &self.layers_image_upload_buffer,
            TextureSampler::RenderTasks => &self.render_tasks_image_upload_buffer,
            _=> unreachable!(),
        };
        let width: u32 = size[0] as u32;
        let height: u32 = size[1] as u32;
        let image_stride = 4 as usize;
        let row_pitch: u32 = width * image_stride as u32;
        {
            let memory = gfx::memory::cast_slice(memory);
            let mut data = self.device
                .acquire_mapping_writer::<u8>(&buffer, 0..(height * row_pitch) as u64)
                .unwrap();
            for y in 0 .. height as usize {
                let row = &(*memory)[y*(width as usize)*image_stride .. (y+1)*(width as usize)*image_stride];
                let dest_base = y * row_pitch as usize;
                data[dest_base .. dest_base + row.len()].copy_from_slice(row);
            }
            self.device.release_mapping_writer(data);
        }

        let image_upload_memory = match sampler {
            TextureSampler::ResourceCache => &self.resource_cache_image_upload_memory,
            TextureSampler::Layers => &self.layers_image_upload_memory,
            TextureSampler::RenderTasks => &self.render_tasks_image_upload_memory,
            _=> unreachable!(),
        };

        let image_memory = match sampler {
            TextureSampler::ResourceCache => &self.resource_cache_image,
            TextureSampler::Layers => &self.layers_image,
            TextureSampler::RenderTasks => &self.render_tasks_image,
            _=> unreachable!(),
        };

        let mut frame_fence = self.device.create_fence(false); // TODO: remove

        // copy buffer to texture
        {
            let submit = {
                let mut cmd_buffer = self.command_pool.acquire_command_buffer();

                let image_barrier = m::Barrier::Image {
                    states: (i::Access::empty(), i::ImageLayout::Undefined) ..
                            (i::Access::TRANSFER_WRITE, i::ImageLayout::TransferDstOptimal),
                    target: image_memory,
                    range: COLOR_RANGE.clone(),
                };
                cmd_buffer.pipeline_barrier(PipelineStage::TOP_OF_PIPE .. PipelineStage::TRANSFER, &[image_barrier]);

                cmd_buffer.copy_buffer_to_image(
                    &buffer,
                    &image_memory,
                    i::ImageLayout::TransferDstOptimal,
                    &[command::BufferImageCopy {
                        buffer_offset: 0,
                        buffer_row_pitch: row_pitch,
                        buffer_slice_pitch: row_pitch * (height as u32),
                        image_layers: i::SubresourceLayers {
                            aspects: i::AspectFlags::COLOR,
                            level: 0,
                            layers: 0 .. 1,
                        },
                        image_offset: command::Offset { x: 0, y: 0, z: 0 },
                        image_extent: d::Extent { width, height, depth: 1 },
                    }]);

                let image_barrier = m::Barrier::Image {
                    states: (i::Access::TRANSFER_WRITE, i::ImageLayout::TransferDstOptimal) ..
                            (i::Access::SHADER_READ, i::ImageLayout::ShaderReadOnlyOptimal),
                    target: image_memory,
                    range: COLOR_RANGE.clone(),
                };
                cmd_buffer.pipeline_barrier(PipelineStage::TRANSFER .. PipelineStage::BOTTOM_OF_PIPE, &[image_barrier]);

                cmd_buffer.finish()
            };

            let submission = Submission::new()
                .submit(&[submit]);
            self.queue_group.queues[0].submit(submission, Some(&mut frame_fence));

            self.device.wait_for_fences(&[&frame_fence], d::WaitFor::All, !0);
        }
        self.device.destroy_fence(frame_fence);
    }

    #[cfg(not(feature = "dx11"))]
    pub fn update_image_data(
        &mut self, pixels: &[u8],
        texture_id: &TextureId,
        x0: u32,
        y0: u32,
        width: u32,
        height: u32,
        layer_index: i32,
        stride: Option<u32>,
        offset: usize)
    {
        println!("update_image_data={:?}", texture_id);
        /*let data = {
            let texture = self.image_textures.get(texture_id).unwrap();
            match texture.format {
                ImageFormat::A8 => convert_data_to_rgba8(width as usize, height as usize, pixels, A_STRIDE),
                ImageFormat::RG8 => convert_data_to_rgba8(width as usize, height as usize, pixels, RG_STRIDE),
                ImageFormat::RGB8 => convert_data_to_rgba8(width as usize, height as usize, pixels, RGB_STRIDE),
                ImageFormat::BGRA8 => {
                    let row_length = match stride {
                        Some(value) => value as usize / RGBA_STRIDE,
                        None => width as usize,
                    };
                    let data_pitch = row_length * RGBA_STRIDE;
                    convert_data_to_bgra8(width as usize, height as usize, data_pitch, pixels)
                }
                _ => unimplemented!(),
            }
        };
        self.update_image_texture(texture_id, [x0 as u16, y0 as u16], [width as u16, height as u16], data.as_slice(), layer_index);*/
    }

    #[cfg(all(target_os = "windows", feature="dx11"))]
    pub fn update_image_data(
        &mut self, pixels: &[u8],
        texture_id: &TextureId,
        x0: u32,
        y0: u32,
        width: u32,
        height: u32,
        layer_index: i32,
        stride: Option<u32>,
        offset: usize)
    {
        println!("update_image_data={:?}", texture_id);
        /*let mut texture = self.image_textures.get_mut(texture_id).unwrap();
        let data = {
            match texture.format {
                ImageFormat::A8 => convert_data_to_rgba8(width as usize, height as usize, pixels, A_STRIDE),
                ImageFormat::RG8 => convert_data_to_rgba8(width as usize, height as usize, pixels, RG_STRIDE),
                ImageFormat::RGB8 => convert_data_to_rgba8(width as usize, height as usize, pixels, RGB_STRIDE),
                ImageFormat::BGRA8 => {
                    let row_length = match stride {
                        Some(value) => value as usize / RGBA_STRIDE,
                        None => width as usize,
                    };
                    let data_pitch = row_length * RGBA_STRIDE;
                    convert_data_to_bgra8(width as usize, height as usize, data_pitch, pixels)
                }
                _ => unimplemented!(),
            }
        };
        let data_pitch = texture.get_size().0 as usize * RGBA_STRIDE;
        batch_image_texture_data(&mut texture, x0 as usize, y0 as usize, width as usize, height as usize, data_pitch, data.as_slice());
        self.image_batch_set.insert(texture_id.clone());*/
    }

    pub fn update_image_texture(&mut self, texture_id: &TextureId, offset: [u16; 2], size: [u16; 2], memory: &[u8], layer_index: i32) {
        /*let img_info = gfx::texture::ImageInfoCommon {
            xoffset: offset[0],
            yoffset: offset[1],
            zoffset: layer_index as u16,
            width: size[0],
            height: size[1],
            depth: 1,
            format: (),
            mipmap: 0,
        };

        let data = gfx::memory::cast_slice(memory);
        let texture = self.image_textures.get(texture_id).unwrap();
        self.encoder.update_texture::<_, Rgba8>(&texture.handle, None, img_info, data).unwrap();*/
    }

    pub fn end_frame(&mut self) {
        debug_assert!(self.inside_frame);
        self.inside_frame = false;
        self.frame_id.0 += 1;
    }

    pub fn copy_texture(
        &mut self,
        src: Option<(&TextureId, i32)>, dst_id: &TextureId,
        src_rect: Option<DeviceIntRect>, dest_rect: DeviceIntRect)
    {
        /*let src_tex = match src {
            Some((src_id, _)) => self.cache_rgba8_textures.get(&src_id).unwrap().handle.raw(),
            None => self.main_color.raw().get_texture(),
        };
        let dst_tex = self.cache_rgba8_textures.get(&dst_id).unwrap().handle.raw();
        let src_rect = src_rect.unwrap_or_else(|| {
            let (w, h, _, _) = src_tex.get_info().kind.get_dimensions();
            DeviceIntRect::new(DeviceIntPoint::zero(), DeviceIntSize::new(w as i32, h as i32))
        });
        let src_info = gfx::texture::RawImageInfo {
            xoffset: src_rect.origin.x as u16,
            yoffset: src_rect.origin.y as u16,
            zoffset: 0,
            width: src_rect.size.width as u16,
            height: src_rect.size.height as u16,
            depth: 0,
            format: ColorFormat::get_format(),
            mipmap: 0,
        };
        /*let src = gfx::texture::TextureCopyRegion {
            texture: src_tex.handle.clone(),
            kind: src_tex.handle.get_info().kind,
            cube_face: None,
            info: src_info,
        };*/

        let dst_info = gfx::texture::RawImageInfo {
            xoffset: dest_rect.origin.x as u16,
            yoffset: dest_rect.origin.y as u16,
            zoffset: 0,
            width: dest_rect.size.width as u16,
            height: dest_rect.size.height as u16,
            depth: 0,
            format: ColorFormat::get_format(),
            mipmap: 0,
        };
        /*let dst = gfx::texture::TextureCopyRegion {
            texture: dst_tex.handle.clone(),
            kind: dst_tex.handle.get_info().kind,
            cube_face: None,
            info: dst_info,
        };*/
        println!("src_id={:?} src_info={:?}", src, src_info);
        println!("dst_id={:?} dst_info={:?}", dst_id, dst_info);
        self.encoder.copy_texture_to_texture_raw(
            &src_tex, None, src_info,
            &dst_tex, None, dst_info).unwrap();*/
    }

    pub fn clear_target(&mut self,
                        color: Option<[f32; 4]>,
                        depth: Option<f32>) {
        /*if let Some(color) = color {
            self.encoder.clear(&self.main_color, [color[0], color[1], color[2], color[3]]);
        }

        if let Some(depth) = depth {
            self.encoder.clear_depth(&self.main_depth, depth);
        }*/
    }

    pub fn clear_render_target_alpha(&mut self, texture_id: &TextureId, color: [f32; 4]) {
        //self.encoder.clear(&self.cache_a8_textures.get(texture_id).unwrap().rtv.clone(), color);
    }

    pub fn clear_render_target_color(&mut self, texture_id: &TextureId, color: Option<[f32; 4]>, depth: f32) {
        /*let tex = self.cache_rgba8_textures.get(texture_id).unwrap();
        if let Some(color) = color {
            self.encoder.clear(&tex.rtv.clone(), color);
        }
        self.encoder.clear_depth(&tex.dsv.clone(), depth);*/
    }

    #[cfg(not(feature = "dx11"))]
    pub fn flush(&mut self) {
        //self.encoder.flush(&mut self.device);
    }
    #[cfg(all(target_os = "windows", feature="dx11"))]
    pub fn flush(&mut self) {
        /*for texture_id in self.image_batch_set.clone() {
            println!("flush batched image {:?}", texture_id);
            let (width, height, data) = {
                let texture = self.image_textures.get(&texture_id).expect("Didn't find texture!");
                let (w, h) = texture.get_size();
                (w, h, &texture.data.clone())
            };
            self.update_image_texture(&texture_id, [0, 0], [width as u16, height as u16], data.as_slice(), 0);
        }
        self.image_batch_set.clear();
        self.encoder.flush(&mut self.device);*/
    }
//}

//impl<B: gfx::Backend> Drop for Device<B> {
//    fn drop(&mut self) {
    pub fn cleanup(&mut self) {
        println!("Dropping!");
        // cleanup!
        //self.device.destroy_command_pool(self.command_pool.downgrade());
        //let _ = &self.command_pool;
        /*self.device.destroy_descriptor_pool(self.desc_pool);
        self.device.destroy_descriptor_set_layout(self.set_layout);

        #[cfg(any(feature = "vulkan", feature = "dx12", feature = "metal", feature = "gl"))]
        {
            self.device.destroy_shader_module(vs_module);
            self.device.destroy_shader_module(fs_module);
        }
        #[cfg(all(feature = "metal", feature = "metal_argument_buffer"))]
        self.device.destroy_shader_module(shader_lib);

        self.device.destroy_buffer(self.image_upload_buffer);
        self.device.destroy_image(self.image_logo);
        self.device.destroy_image_view(self.image_srv);
        self.device.destroy_sampler(self.sampler);
        self.device.destroy_pipeline_layout(self.pipeline_layout);
        self.device.free_memory(self.image_memory);
        self.device.free_memory(self.image_upload_memory);*/
        //self.device.destroy_semaphore(self.frame_semaphore);
        //let _ = &self.frame_semaphore;
        //self.device.destroy_buffer(self.vertex_buffer);
        let _ = &self.vertex_buffer;
        //self.device.free_memory(self.buffer_memory);
        let _ = &self.buffer_memory;
        //self.device.destroy_renderpass(self.render_pass);
        let _ = &self.render_pass;
        for pipeline in self.pipelines.drain(..) {
            if let Ok(pipeline) = pipeline {
                self.device.destroy_graphics_pipeline(pipeline);
            }
        }
        for framebuffer in self.framebuffers.drain(..) {
            self.device.destroy_framebuffer(framebuffer);
        }
        for (image, rtv) in self.frame_images.drain(..) {
            self.device.destroy_image_view(rtv);
            self.device.destroy_image(image);
        }
    }
}

pub fn convert_data_to_rgba8(width: usize, height: usize, data: &[u8], orig_stride: usize) -> Vec<u8> {
    let mut new_data = vec![0u8; width * height * RGBA_STRIDE];
    for s in 0..orig_stride {
        for h in 0..height {
            for w in 0..width {
                new_data[s+(w*RGBA_STRIDE)+h*width*RGBA_STRIDE] = data[s+(w*orig_stride)+h*width*orig_stride];
            }
        }
    }
    return new_data;
}

fn convert_data_to_bgra8(width: usize, height: usize, data_pitch: usize, data: &[u8]) -> Vec<u8> {
    let mut new_data = vec![0u8; width * height * RGBA_STRIDE];
    for j in 0..height {
        for i in 0..width {
            let offset = i*RGBA_STRIDE + j*RGBA_STRIDE*width;
            let src = &data[j * data_pitch + i * RGBA_STRIDE ..];
            assert!(offset + 3 < new_data.len()); // optimization
            // convert from BGRA
            new_data[offset + 0] = src[2];
            new_data[offset + 1] = src[1];
            new_data[offset + 2] = src[0];
            new_data[offset + 3] = src[3];
        }
    }
    return new_data;
}

/*fn batch_image_texture_data(texture: &mut ImageTexture<Rgba8>,
    x_offset: usize, y_offset: usize,
    width: usize, height: usize,
    data_pitch: usize, new_data: &[u8])
{
    println!("batch_texture_data");
    println!("x0={:?} y0={:?} width={:?} height={:?} data_pitch={:?} new_data.len={:?}",
              x_offset, y_offset, width, height, data_pitch, new_data.len());
    for j in 0..height {
        for i in 0..width {
            let offset = (j+y_offset)*data_pitch + (i + x_offset)*RGBA_STRIDE;
            let src = &new_data[j * RGBA_STRIDE*width + i * RGBA_STRIDE .. (j * RGBA_STRIDE*width + i * RGBA_STRIDE)+4];
            assert!(offset + 3 < texture.data.len());
            texture.data[offset + 0] = src[0];
            texture.data[offset + 1] = src[1];
            texture.data[offset + 2] = src[2];
            texture.data[offset + 3] = src[3];
        }
    }
}*/

// Profiling stuff

#[cfg(feature = "query")]
const MAX_PROFILE_FRAMES: usize = 4;

pub trait NamedTag {
    fn get_label(&self) -> &str;
}

#[derive(Debug, Clone)]
pub struct GpuTimer<T> {
    pub tag: T,
    pub time_ns: u64,
}

#[derive(Debug, Clone)]
pub struct GpuSampler<T> {
    pub tag: T,
    pub count: u64,
}

#[cfg(feature = "query")]
pub struct QuerySet<T> {
    set: Vec<gl::GLuint>,
    data: Vec<T>,
    pending: gl::GLuint,
}

#[cfg(feature = "query")]
impl<T> QuerySet<T> {
    fn new(set: Vec<gl::GLuint>) -> Self {
        QuerySet {
            set,
            data: Vec::new(),
            pending: 0,
        }
    }

    fn reset(&mut self) {
        self.data.clear();
        self.pending = 0;
    }

    fn add(&mut self, value: T) -> Option<gl::GLuint> {
        assert_eq!(self.pending, 0);
        self.set.get(self.data.len()).cloned().map(|query_id| {
            self.data.push(value);
            self.pending = query_id;
            query_id
        })
    }

    fn take<F: Fn(&mut T, gl::GLuint)>(&mut self, fun: F) -> Vec<T> {
        let mut data = mem::replace(&mut self.data, Vec::new());
        for (value, &query) in data.iter_mut().zip(self.set.iter()) {
            fun(value, query)
        }
        data
    }
}

#[cfg(feature = "query")]
pub struct GpuFrameProfile<T> {
    gl: Rc<gl::Gl>,
    timers: QuerySet<GpuTimer<T>>,
    samplers: QuerySet<GpuSampler<T>>,
    frame_id: FrameId,
    inside_frame: bool,
}

#[cfg(feature = "query")]
impl<T> GpuFrameProfile<T> {
    const MAX_TIMERS_PER_FRAME: usize = 256;
    // disable samplers on OSX due to driver bugs
    #[cfg(target_os = "macos")]
    const MAX_SAMPLERS_PER_FRAME: usize = 0;
    #[cfg(not(target_os = "macos"))]
    const MAX_SAMPLERS_PER_FRAME: usize = 16;

    fn new(gl: Rc<gl::Gl>) -> Self {
        assert_eq!(gl.get_type(), gl::GlType::Gl);
        let time_queries = gl.gen_queries(Self::MAX_TIMERS_PER_FRAME as _);
        let sample_queries = gl.gen_queries(Self::MAX_SAMPLERS_PER_FRAME as _);

        GpuFrameProfile {
            gl,
            timers: QuerySet::new(time_queries),
            samplers: QuerySet::new(sample_queries),
            frame_id: FrameId(0),
            inside_frame: false,
        }
    }

    fn begin_frame(&mut self, frame_id: FrameId) {
        self.frame_id = frame_id;
        self.timers.reset();
        self.samplers.reset();
        self.inside_frame = true;
    }

    fn end_frame(&mut self) {
        self.done_marker();
        self.done_sampler();
        self.inside_frame = false;
    }

    fn done_marker(&mut self) {
        debug_assert!(self.inside_frame);
        if self.timers.pending != 0 {
            self.gl.end_query(gl::TIME_ELAPSED);
            self.timers.pending = 0;
        }
    }

    fn add_marker(&mut self, tag: T) -> GpuMarker
    where
        T: NamedTag,
    {
        self.done_marker();

        let marker = GpuMarker::new(&self.gl, tag.get_label());

        if let Some(query) = self.timers.add(GpuTimer { tag, time_ns: 0 }) {
            self.gl.begin_query(gl::TIME_ELAPSED, query);
        }

        marker
    }

    fn done_sampler(&mut self) {
        debug_assert!(self.inside_frame);
        if self.samplers.pending != 0 {
            self.gl.end_query(gl::SAMPLES_PASSED);
            self.samplers.pending = 0;
        }
    }

    fn add_sampler(&mut self, tag: T)
    where
        T: NamedTag,
    {
        self.done_sampler();

        if let Some(query) = self.samplers.add(GpuSampler { tag, count: 0 }) {
            self.gl.begin_query(gl::SAMPLES_PASSED, query);
        }
    }

    fn is_valid(&self) -> bool {
        !self.timers.set.is_empty() || !self.samplers.set.is_empty()
    }

    fn build_samples(&mut self) -> (Vec<GpuTimer<T>>, Vec<GpuSampler<T>>) {
        debug_assert!(!self.inside_frame);
        let gl = &self.gl;

        (
            self.timers.take(|timer, query| {
                timer.time_ns = gl.get_query_object_ui64v(query, gl::QUERY_RESULT)
            }),
            self.samplers.take(|sampler, query| {
                sampler.count = gl.get_query_object_ui64v(query, gl::QUERY_RESULT)
            }),
        )
    }
}

#[cfg(feature = "query")]
impl<T> Drop for GpuFrameProfile<T> {
    fn drop(&mut self) {
        if !self.timers.set.is_empty() {
            self.gl.delete_queries(&self.timers.set);
        }
        if !self.samplers.set.is_empty() {
            self.gl.delete_queries(&self.samplers.set);
        }
    }
}

#[cfg(feature = "query")]
pub struct GpuProfiler<T> {
    frames: [GpuFrameProfile<T>; MAX_PROFILE_FRAMES],
    next_frame: usize,
}

#[cfg(feature = "query")]
impl<T> GpuProfiler<T> {
    pub fn new(gl: &Rc<gl::Gl>) -> Self {
        GpuProfiler {
            next_frame: 0,
            frames: [
                GpuFrameProfile::new(Rc::clone(gl)),
                GpuFrameProfile::new(Rc::clone(gl)),
                GpuFrameProfile::new(Rc::clone(gl)),
                GpuFrameProfile::new(Rc::clone(gl)),
            ],
        }
    }

    pub fn build_samples(&mut self) -> Option<(FrameId, Vec<GpuTimer<T>>, Vec<GpuSampler<T>>)> {
        let frame = &mut self.frames[self.next_frame];
        if frame.is_valid() {
            let (timers, samplers) = frame.build_samples();
            Some((frame.frame_id, timers, samplers))
        } else {
            None
        }
    }

    pub fn begin_frame(&mut self, frame_id: FrameId) {
        let frame = &mut self.frames[self.next_frame];
        frame.begin_frame(frame_id);
    }

    pub fn end_frame(&mut self) {
        let frame = &mut self.frames[self.next_frame];
        frame.end_frame();
        self.next_frame = (self.next_frame + 1) % MAX_PROFILE_FRAMES;
    }

    pub fn add_marker(&mut self, tag: T) -> GpuMarker
    where
        T: NamedTag,
    {
        self.frames[self.next_frame].add_marker(tag)
    }

    pub fn add_sampler(&mut self, tag: T)
    where
        T: NamedTag,
    {
        self.frames[self.next_frame].add_sampler(tag)
    }

    pub fn done_sampler(&mut self) {
        self.frames[self.next_frame].done_sampler()
    }
}

#[cfg(not(feature = "query"))]
pub struct GpuProfiler<T>(Option<T>);

#[cfg(not(feature = "query"))]
impl<T> GpuProfiler<T> {
    pub fn new() -> Self {
        GpuProfiler(None)
    }

    pub fn build_samples(&mut self) -> Option<(FrameId, Vec<GpuTimer<T>>, Vec<GpuSampler<T>>)> {
        None
    }

    pub fn begin_frame(&mut self, _: FrameId) {}

    pub fn end_frame(&mut self) {}

    pub fn add_marker(&mut self, _: T) -> GpuMarker {
        GpuMarker {}
    }

    pub fn add_sampler(&mut self, _: T) {}

    pub fn done_sampler(&mut self) {}
}


#[must_use]
pub struct GpuMarker {
    #[cfg(feature = "query")]
    gl: Rc<gl::Gl>,
}

#[cfg(feature = "query")]
impl GpuMarker {
    pub fn new(gl: &Rc<gl::Gl>, message: &str) -> Self {
        debug_assert_eq!(gl.get_type(), gl::GlType::Gl);
        gl.push_group_marker_ext(message);
        GpuMarker { gl: Rc::clone(gl) }
    }

    pub fn fire(gl: &gl::Gl, message: &str) {
        debug_assert_eq!(gl.get_type(), gl::GlType::Gl);
        gl.insert_event_marker_ext(message);
    }
}

#[cfg(feature = "query")]
impl Drop for GpuMarker {
    fn drop(&mut self) {
        self.gl.pop_group_marker_ext();
    }
}

#[cfg(not(feature = "query"))]
impl GpuMarker {
    #[inline]
    pub fn new(message: &str) -> Self {
        GpuMarker{}
    }
    #[inline]
    pub fn fire(_: &str) {}
}

// The stuff we don't need but webrender requires

pub trait FileWatcherHandler: Send {
    fn file_changed(&self, path: PathBuf);
}

#[derive(Debug)]
pub enum VertexAttributeKind {
    F32,
    U8Norm,
    I32,
    U16,
}

#[derive(Debug)]
pub struct VertexAttribute {
    pub name: &'static str,
    pub count: u32,
    pub kind: VertexAttributeKind,
}

#[derive(Debug)]
pub struct VertexDescriptor {
    pub vertex_attributes: &'static [VertexAttribute],
    pub instance_attributes: &'static [VertexAttribute],
}

impl VertexAttributeKind {
    fn size_in_bytes(&self) -> u32 {
        match *self {
            VertexAttributeKind::F32 => 4,
            VertexAttributeKind::U8Norm => 1,
            VertexAttributeKind::I32 => 4,
            VertexAttributeKind::U16 => 2,
        }
    }
}

impl VertexAttribute {
    fn size_in_bytes(&self) -> u32 {
        self.count * self.kind.size_in_bytes()
    }
}

impl VertexDescriptor {
    fn instance_stride(&self) -> u32 {
        self.instance_attributes
            .iter()
            .map(|attr| attr.size_in_bytes())
            .sum()
    }
}

#[derive(Debug, Copy, Clone)]
pub enum VertexUsageHint {
    Static,
    Dynamic,
    Stream,
}

#[derive(Clone, Debug)]
pub enum ShaderError {
    Compilation(String, String), // name, error mssage
    Link(String, String),        // name, error message
}
