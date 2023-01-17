class GraphWalker(object):
    '''Base class for iterating over SparseGraph objects.
    '''
    def __init__(self, graph):
        self.queue = None  # nodes to visit next
        self.visited = None  # nodes we've seen
        self.waiting = None  # these wait for some of their parents
        self.graph = graph

    def walkGraph(self):
        print("walkGraph")
        print("--------------------------------------")

        self.visited = set()
        self.waiting = set()
        self.queue = self.graph.roots[:]
        self.sortQueue()
        while self.queue:
            src_rev = self.queue.pop()
            if not self._shouldHandle(src_rev):
                continue
            self.visited.add(src_rev)
            self.waiting -= self.graph.parents[src_rev]
            self.handlerev(src_rev)
            children = self.graph.children[src_rev]
            for child in children:
                if self._shouldHandle(child):
                    self.queue.append(child)
                else:
                    self.waiting.add(src_rev)
            self.sortQueue()

    def _shouldHandle(self, src_rev):
        if src_rev in self.visited:
            return False
        for src_parent in self.graph.parents[src_rev]:
            if src_parent not in self.visited:
                # didn't process all parents yet, other roots should get here
                return False
        return True

    def sortQueue(self):
        self.queue.sort(key=lambda commit: -self.graph.commit_dates[commit])

    def handlerev(self, src_rev):
        raise NotImplementedError
