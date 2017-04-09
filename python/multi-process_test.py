# from multiprocessing import Process
# import os
#
# def info(title):
#     print title
#     print 'module name:', __name__
#     if hasattr(os, 'getppid'):  # only available on Unix
#         print 'parent process:', os.getppid()
#     print 'process id:', os.getpid()
#
# def f(name):
#     info('function f')
#     print 'hello', name
#
# if __name__ == '__main__':
#     info('main line')
#     p = Process(target=f, args=('bob',))
#     p.start()
#     p.join()


from multiprocessing import Process, Queue

def f(q, iter):
    q.put([42, None, 'hello', iter])

if __name__ == '__main__':
    q = Queue()
    for i in range(23):
        p = Process(target=f, args=(q,i,))
        p.start()
        print q.get()    # prints "[42, None, 'hello']"
        p.join()
