export interface ServiceCategory {
  name: string;
  slug: string;
  icon: string;
  description: string;
  gradient: string;
}

export const services: ServiceCategory[] = [
  {
    name: 'General Construction',
    slug: 'general-construction',
    icon: '🏗️',
    description: 'New builds, renovations, extensions and general contracting',
    gradient: 'from-amber-50 to-orange-50',
  },
  {
    name: 'Architecture & Design',
    slug: 'architecture-design',
    icon: '📐',
    description: 'Architectural planning, blueprints and structural design',
    gradient: 'from-sky-50 to-blue-50',
  },
  {
    name: 'Interior Design',
    slug: 'interior-design',
    icon: '🎨',
    description: 'Space planning, furniture selection and interior styling',
    gradient: 'from-pink-50 to-rose-50',
  },
  {
    name: 'Plumbing',
    slug: 'plumbing',
    icon: '🔧',
    description: 'Pipe installation, repairs, water systems and drainage',
    gradient: 'from-cyan-50 to-teal-50',
  },
  {
    name: 'Electrical Work',
    slug: 'electrical-work',
    icon: '⚡',
    description: 'Wiring, panel upgrades, lighting and electrical repairs',
    gradient: 'from-yellow-50 to-amber-50',
  },
  {
    name: 'Masonry & Tiling',
    slug: 'masonry-tiling',
    icon: '🧱',
    description: 'Brickwork, stone walls, floor and wall tiling',
    gradient: 'from-red-50 to-orange-50',
  },
  {
    name: 'Carpentry & Woodwork',
    slug: 'carpentry-woodwork',
    icon: '🪵',
    description: 'Custom furniture, cabinetry, doors and woodworking',
    gradient: 'from-amber-50 to-yellow-50',
  },
  {
    name: 'Painting & Finishing',
    slug: 'painting-finishing',
    icon: '🖌️',
    description: 'Interior and exterior painting, textures and wall finishes',
    gradient: 'from-violet-50 to-purple-50',
  },
  {
    name: 'Roofing',
    slug: 'roofing',
    icon: '🏠',
    description: 'Roof installation, repair, waterproofing and insulation',
    gradient: 'from-stone-50 to-zinc-100',
  },
  {
    name: 'Landscaping',
    slug: 'landscaping',
    icon: '🌿',
    description: 'Garden design, lawn care, outdoor structures and planting',
    gradient: 'from-emerald-50 to-green-50',
  },
  {
    name: 'Welding & Metalwork',
    slug: 'welding-metalwork',
    icon: '⚙️',
    description: 'Gates, grills, railings and custom metal fabrication',
    gradient: 'from-slate-50 to-gray-100',
  },
  {
    name: 'Waterproofing',
    slug: 'waterproofing',
    icon: '💧',
    description: 'Basement, roof and wall waterproofing solutions',
    gradient: 'from-blue-50 to-indigo-50',
  },
];
