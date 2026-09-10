import SwiftUI

struct FrameCanvas: View {
    let image: UIImage
    @Binding var roi: [Double]?
    let analysis: FrameAnalysis?
    let target: String
    let changed: () -> Void
    var body: some View {
        GeometryReader { geometry in
            let rect=imageRect(in:geometry.size)
            ZStack {
                Color.black
                Image(uiImage:image).resizable().frame(width:rect.width,height:rect.height).position(x:rect.midX,y:rect.midY)
                Canvas { context,_ in
                    if target == "redness" {
                        if let roi,roi.count==4 {
                            let selected=CGRect(x:rect.minX+roi[0]*rect.width,y:rect.minY+roi[1]*rect.height,width:roi[2]*rect.width,height:roi[3]*rect.height)
                            context.stroke(Path(selected),with:.color(.cyan),lineWidth:2)
                        }
                        if let analysis {
                            for contour in analysis.redness.vessel_contours_xy {
                                var path=Path()
                                for (index,p) in contour.enumerated() where p.count==2 {
                                    let point=CGPoint(x:rect.minX+p[0]/analysis.image_size_wh[0]*rect.width,y:rect.minY+p[1]/analysis.image_size_wh[1]*rect.height)
                                    if index==0 { path.move(to:point) } else { path.addLine(to:point) }
                                }
                                path.closeSubpath();context.fill(path,with:.color(.pink.opacity(0.5)))
                            }
                        }
                    } else if let analysis {
                        for (fit,color) in [(analysis.pupil,Color.green),(analysis.iris,Color.pink)] {
                            guard let fit else { continue }
                            var path=Path()
                            for step in 0...120 {
                                let theta=Double(step)/120*2*Double.pi,angle=fit.angle_degrees*Double.pi/180
                                let x=cos(theta)*fit.axes_wh[0]/2,y=sin(theta)*fit.axes_wh[1]/2
                                let px=fit.center_xy[0]+x*cos(angle)-y*sin(angle),py=fit.center_xy[1]+x*sin(angle)+y*cos(angle)
                                let point=CGPoint(x:rect.minX+px/analysis.image_size_wh[0]*rect.width,y:rect.minY+py/analysis.image_size_wh[1]*rect.height)
                                if step==0 { path.move(to:point) } else { path.addLine(to:point) }
                            }
                            context.stroke(path,with:.color(color),lineWidth:2)
                        }
                    }
                }
            }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:4).onChanged { gesture in
                guard target == "redness",rect.contains(gesture.startLocation) else { return }
                let end=CGPoint(x:min(rect.maxX,max(rect.minX,gesture.location.x)),y:min(rect.maxY,max(rect.minY,gesture.location.y)))
                let x=min(gesture.startLocation.x,end.x),y=min(gesture.startLocation.y,end.y)
                let w=abs(end.x-gesture.startLocation.x),h=abs(end.y-gesture.startLocation.y)
                guard w>4,h>4 else { return }
                roi=[(x-rect.minX)/rect.width,(y-rect.minY)/rect.height,w/rect.width,h/rect.height];changed()
            })
        }.clipShape(RoundedRectangle(cornerRadius:12))
    }
    private func imageRect(in size: CGSize) -> CGRect {
        let scale=min(size.width/image.size.width,size.height/image.size.height)
        let width=image.size.width*scale,height=image.size.height*scale
        return CGRect(x:(size.width-width)/2,y:(size.height-height)/2,width:width,height:height)
    }
}
