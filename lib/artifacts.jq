def gsub_workspace(d):
  map(map(d |= if . then gsub("\\${workspace}"; $workspace) else empty end));

def custom_artifacts(d):
  .buildkite.artifacts // []
  | map(select(.step_types | contains([$step_type])))
  | map(d // empty)
  | gsub_workspace(.from)
  | gsub_workspace(.to)
  | flatten;

{
        ("artifacts#" + $plugin_version): {
         "upload": ($upload_defaults + custom_artifacts(.upload)),
         "download": ($download_defaults + custom_artifacts(.download))
        }
}
