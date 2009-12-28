;; microblog-user.lisp - A microblog service user.
;; Copyright (C) 2009  Rob Myers rob@robmyers.org
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.
;;
;; You should have received a copy of the GNU Affero General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Package
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :microblog-bot)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; microblog-user
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass microblog-user ()
  ((user-nickname :accessor user-nickname
		  :initarg :nickname)
   (user-password :accessor user-password
		  :initarg :password)))

(defmethod coherent? ((object microblog-user))
  "Check whether the object is in a coherent state"
  (and (user-nickname object) (user-password object)))

(defun user-id-for-screen-name (name)
  ;; This is ambiguous. It would be better to use screen_name when supported
  (let ((user-info (or (cl-twit:m-user-show :id name)
		    (error "Can't get user info in user-id-for-screen-name"))))
    (assert user-info)
    (or (cl-twit::id user-info)
	(error "Can't get user id in user-id-for-screen-name"))))

(defmacro with-microblog-user (user &body body)
  "Log in, execture the body, log out"
  (let ((result (gensym)))
    `(progn
       (cl-twit:with-session ((user-nickname ,user) 
			      (user-password ,user) 
			      :authenticatep t)
	 (debug-msg "With user ~a" ,user)
	 (let ((,result (progn ,@body)))
	   (debug-msg "Finished with user ~a" ,user) 
	   ;; with-session doesn't currently do this, remove if it ever does.
	   (cl-twit:logout)
	   ,result)))))
