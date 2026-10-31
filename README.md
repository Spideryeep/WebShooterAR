# Web Shooter AR

Native iPhone ARKit prototype. It uses ARKit world tracking and vertical-plane raycasts to anchor web effects to detected real-world walls. Vision hand-pose recognition looks for the classic index-and-pinky-extended gesture. You can also tap the view to test wall placement.

## Build
This repository includes an XcodeGen `project.yml` and a GitHub Actions workflow. The workflow builds an unsigned iOS app on GitHub-hosted macOS. Installing on a physical iPhone still requires Apple code signing with a development team.

## Notes
This is an early prototype. The current web is a simple anchored visual strand; it is not yet a physically simulated web rope that stretches from the moving hand to the wall.
