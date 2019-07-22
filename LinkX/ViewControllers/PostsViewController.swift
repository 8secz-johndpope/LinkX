//
//  PostsViewController.swift
//  LinkX
//
//  Created by Rodney Gainous Jr on 7/19/19.
//  Copyright © 2019 CodeSigned. All rights reserved.
//

import UIKit
import Firebase
import FirebaseDatabase
import NotificationCenter

class PostsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, PostCellDelegate {

    @IBOutlet var addPostButton: UIButton!
    @IBOutlet var tableView: UITableView!
    
    var posts = [Post]() {
        didSet {
            if posts.count > 0 {
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    var fetchedUser: User?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRefresh), name: NSNotification.Name.updateHomeFeed, object: nil)
        
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(UINib(nibName: "PostTableViewCell", bundle: nil), forCellReuseIdentifier: "PostTableViewCell")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        fetchPostsForCurrentUser()
    }
    
    @objc private func handleRefresh() {
        fetchPostsForCurrentUser()
    }
    
    func shareTouched(post: Post, image: UIImage) {
        guard let link = post.publicUrl else { return }
        
        guard let watermark = UIImage(named: "link-icon-small"), let finalImage = addWatermark(image: image, watermark: watermark), let title = post.title else {
            return
        }
        
        // set up activity view controller
        let itemsToShare : [Any] = [ finalImage, "\(title) - \(link) #LinkX" ]
        let activityViewController = UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = self.view // so that iPads won't crash
        
        // present the view controller
        self.present(activityViewController, animated: true, completion: nil)
    }
    
    func addWatermark(image: UIImage, watermark: UIImage) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0)
        image.draw(in: CGRect(x: 0.0, y: 0.0, width: image.size.width, height: image.size.height))
        watermark.draw(in: CGRect(x: image.size.width - watermark.size.width, y: 0.0, width: watermark.size.width, height: watermark.size.height))
        
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return result
    }
    
    func skepticalTouched(post: Post) {
        
    }
    
    func shockedTouched(post: Post) {
        
    }
    
    func updatePost(post: Post) -> Post? {
        for i in 0..<posts.count {
            if posts[i].id == post.id {
                posts[i] = post
                return posts[i]
            }
        }
        
        return nil
    }
    
    func clapTouched(post: Post) {
        guard let uid = Auth.auth().currentUser?.uid, let pid = post.id else { return }
        
        if post.clappedByCurrentUser {
            Database.database().reference().child("claps").child(pid).child(uid).removeValue { (err, _) in
                if let err = err {
                    print("Failed to unclap post:", err)
                    return
                }

                var newPost = self.updatePost(post: post)
                newPost?.clappedByCurrentUser = false
                newPost?.claps = post.claps - 1
                UIView.performWithoutAnimation {
                    self.tableView.reloadData()
                }
            }
        } else {
            let values = [uid : 1]
            Database.database().reference().child("claps").child(pid).updateChildValues(values) { (err, _) in
                if let err = err {
                    print("Failed to clap post:", err)
                    return
                }

                var newPost = self.updatePost(post: post)
                newPost?.clappedByCurrentUser = true
                newPost?.claps = post.claps + 1
                UIView.performWithoutAnimation {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func bookmarkTouched(post: Post) {
        
    }
    
    func optionsTouched(post: Post) {
        guard let currentLoggedInUserId = Auth.auth().currentUser?.uid else { return }
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        if currentLoggedInUserId == post.user?.uid {
            if let deleteAction = deleteAction(forPost: post) {
                alertController.addAction(deleteAction)
            }
        } else {
            if let reportAction = reportAction(forPost: post) {
                alertController.addAction(reportAction)
            }
            
            if let blockAction = blockAction(forPost: post) {
                alertController.addAction(blockAction)
            }
        }
        present(alertController, animated: true, completion: nil)
    }
    
    private func deleteAction(forPost post: Post) -> UIAlertAction? {
        guard let currentLoggedInUserId = Auth.auth().currentUser?.uid else { return nil }
        
        let action = UIAlertAction(title: "Delete", style: .destructive, handler: { (_) in
            
            let alert = UIAlertController(title: "Delete Post?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Delete", style: .default, handler: { (_) in
                guard let pid = post.id else { return }
                
                Database.database().deletePost(withUID: currentLoggedInUserId, postId: pid) { (_) in
                    if let postIndex = self.posts.index(where: {$0.id == post.id}) {
                        self.posts.remove(at: postIndex)
                        self.tableView.reloadData()
                    }
                }
            }))
            self.present(alert, animated: true, completion: nil)
        })
        return action
    }
    
    private func blockAction(forPost post: Post) -> UIAlertAction? {
        let action = UIAlertAction(title: "Block", style: .destructive) { (_) in
            
            guard let uid = post.user?.uid else { return }
//            Database.database().blockUser(withUID: uid, completion: { (error) in
//                let filteredPosts = self.posts.filter({$0.user.uid != uid})
//                self.posts = filteredPosts
//                self.tableView.reloadData()
//            })
        }
        return action
    }
    
    private func reportAction(forPost post: Post) -> UIAlertAction? {
        let action = UIAlertAction(title: "Report", style: .destructive) { (_) in
            
            guard let uid = post.user?.uid, let pid = post.id else { return }
            Database.database().reportPost(withId: pid, postCreatorId: uid, reason: "General", completion: { (error) in
                let filteredPosts = self.posts.filter({$0.user?.uid != uid})
                self.posts = filteredPosts
                self.tableView.reloadData()
            })
        }
        return action
    }
    
    @IBAction func postTouched(_ sender: Any) {
        performSegue(withIdentifier: "ShowAddPost", sender: self)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 321.0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell =
            tableView.dequeueReusableCell(withIdentifier: "PostTableViewCell", for: indexPath) as? PostTableViewCell else {
                return UITableViewCell()
        }
        
        cell.configure(post: posts[indexPath.row])
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard posts.count > indexPath.row, let url = URL(string: posts[indexPath.row].url ?? "") else {
            return
        }
        
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    private func fetchPostsForCurrentUser() {
        guard let currentLoggedInUserId = Auth.auth().currentUser?.uid else { return }
        
        tableView.refreshControl?.beginRefreshing()
        
        Database.database().fetchAllPosts(withUID: currentLoggedInUserId, completion: { (posts) in
            self.posts.removeAll()
            self.posts.append(contentsOf: posts)
            
            self.posts.sort(by: { (p1, p2) -> Bool in
                return p1.createdAt ?? 0.0 > p2.createdAt ?? 0.0
            })
            
            self.tableView.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }) { (err) in
            self.tableView.refreshControl?.endRefreshing()
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension NSNotification.Name {
    static var updateHomeFeed = NSNotification.Name(rawValue: "updateFeed")
}
