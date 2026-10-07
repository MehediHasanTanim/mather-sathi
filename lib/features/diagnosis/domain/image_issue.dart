/// Why a photo cannot be used. The first five mirror the cloud contract
/// (`image_issue`); [tooSmall] is raised only by the client's resolution check.
enum ImageIssue { none, blurry, notAPlant, wrongCrop, tooDark, tooSmall }
