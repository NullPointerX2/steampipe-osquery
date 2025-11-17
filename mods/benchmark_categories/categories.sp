benchmark "benchmark_categories" {
  title         = "Benchmark Categories"
  description   = "An implementation of the nine defined benchmark categories."
  children = [
    benchmark.access_to_fs,
  ]
}