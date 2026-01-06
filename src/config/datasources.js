console.log('VITE_DATA_BASE_URL =', import.meta.env.VITE_DATA_BASE_URL)

export const DATA_BASE_URL =
  import.meta.env.VITE_DATA_BASE_URL || '/data'
